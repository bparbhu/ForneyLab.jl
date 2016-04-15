###########################################
# Shared methods for algorithm construction
###########################################

parameters{T<:ProbabilityDistribution}(message_type::Type{Message{T}}) = message_type.parameters[1].parameters

parameters{T<:ProbabilityDistribution}(distribution_type::Type{T}) = distribution_type.parameters

parameters(type_var::TypeVar) = type_var.ub.parameters

function parameters(data_type::DataType)
    # Extract parameters of type ForneyLab.Message{T<:ForneyLab.MvGaussianDistribution{dims}}
    if data_type <: Message
        return data_type.parameters[1].ub.parameters
    else
        error("parameters function not valid for $(data_type)")
    end
end

function extractParameters(method_signature::SimpleVector, call_signature::Vector{DataType})
    # Constructs a dictionary of parameter variables in method_signature mapped to values in call_signature

    params_dict = Dict()
    for p in 4:length(method_signature) # Loop of indices of inbound types
        if call_signature[p] != Void # Skip irrelevant inbounds
            method_params = parameters(method_signature[p])
            call_params = parameters(call_signature[p])
            for r in 1:length(method_params) # Iterate over all found parameters for that specific inbound and the pairs to the dictionary
                push!(params_dict, method_params[r] => call_params[r])
            end
        end
    end

    return params_dict
end

function extractOutboundType(outbound_arg)
    # Acceps the update rule argument of the outbound and returns a DataType with the parameterized outbound distribution type
    if typeof(outbound_arg) == TypeVar
        return outbound_arg.ub
    elseif typeof(outbound_arg) == DataType
        return outbound_arg
    else
        error("outbound_arg of unrecognized type: $(typeof(outbound_arg))")
    end
end


function collectAllOutboundTypes(rule::Function, call_signature::Vector, node::Node)
    # Collect all outbound distribution types that can be generated with the specified rule and calling_signature combination
    # Note the node argument: this function can be overloaded for specific nodes
    # Returns: outbound_types::Vector{DataType}
    # The entries of outbound_types can be <: ProbabilityDistribution or Approximation

    outbound_types = DataType[]

    for method in methods(rule, call_signature)
        ob_type = extractOutboundType(method.sig.types[3]) # Third entry is always the outbound distribution

        if typeof(node) <: TerminalNode
            ob_type = typeof(node.value)
        elseif !isempty(parameters(ob_type)) # ob_type has parameters that need to be inferred
            params_dict = extractParameters(method.sig.types, call_signature) # Extract parameters and values of inbound types
            outbound_params = parameters(ob_type) # Extract parameters of outbound type

            # Construct parametrized outbound type with substituted values
            param_values = [params_dict[param] for param in outbound_params]
            ob_type = eval(parse("$(ob_type.name){" * join(param_values,", ") * "}")) # Construct the parametrized outbound type
        end

        # Is the method an approximate msg calculation rule?
        if (typeof(method.sig.types[end])==DataType
            && length(method.sig.types[end].parameters)==1
            && method.sig.types[end].parameters[1]<:ApproximationType)

            ob_type = Approximation{ob_type,method.sig.types[end].parameters[1]}
        end

        push!(outbound_types, ob_type)
    end

    return outbound_types
end

function collectAllOutboundTypes(rule::Function, call_signature::Vector, node::Union{GainNode, GainAdditionNode, GainEqualityNode})
    # Outbound type collection overloading for nodes with an (optional) fixed gain

    outbound_types = DataType[]

    for method in methods(rule, call_signature)

        ob_type = extractOutboundType(method.sig.types[3]) # Third entry is always the outbound distribution

        if !isempty(parameters(ob_type)) # Outbound type has parameters that need to be inferred
            params_dict = extractParameters(method.sig.types, call_signature) # Extract parameters and values of inbound types
            outbound_params = parameters(ob_type) # Extract parameters of outbound type

            # Construct new outbound type definition with substituted values
            param_values = Any[]
            for param in outbound_params
                if haskey(params_dict, param)
                    push!(param_values, params_dict[param])
                else # The outbound param is not available in the inbound parameter dictionary; we need to infer it from the fixed gain matrix
                    if param.name == :dims_n
                        push!(param_values, size(node.gain, 1))
                    elseif param.name == :dims_m
                        push!(param_values, size(node.gain, 2))
                    else
                        error("For the gain node with fixed gain, the dimensionalities in the calling signature need to be encoded as {dims_n, dims_m}")
                    end
                end
            end

            ob_type = eval(parse("$(ob_type.name){" * join(param_values, ", ") * "}")) # Construct the type definition of the substituted outbound type
        end

        # Is the method an approximate msg calculation rule?
        if (typeof(method.sig.types[end])==DataType
            && length(method.sig.types[end].parameters)==1
            && method.sig.types[end].parameters[1]<:ApproximationType)

            ob_type = Approximation{ob_type,method.sig.types[end].parameters[1]}
        end

        push!(outbound_types, ob_type)
    end

    return outbound_types
end

function inferOutboundType!(entry::ScheduleEntry)
    # Infer the outbound type from the node type and the types of the inbounds

    inbound_types = entry.inbound_types
    node = entry.node
    exact_call_signature = [typeof(node); Type{Val{entry.outbound_interface_id}}; Any; inbound_types] # Call signature for exact message computation rules

    if isdefined(entry, :outbound_type)
        # The outbound type is already fixed, so we just need to validate that there exists a suitable computation rule

        # Try to find a matching exact rule
        outbound_types = collectAllOutboundTypes(entry.rule, exact_call_signature, node)
        if entry.outbound_type in outbound_types
            return entry
        end

        # Try to find a matching approximate rule
        call_signature = vcat(exact_call_signature, isdefined(entry, :approximation) ? Type{entry.approximation} : Any)
        outbound_types = collectAllOutboundTypes(entry.rule, call_signature, node)
        for outbound_type in outbound_types
            if entry.outbound_type == outbound_type.parameters[1]
                return entry
            end
        end

        error("No suitable calculation rule available for schedule entry:\n$(entry)Inbound types: $(inbound_types).")
    else
        # Infer the outbound type

        # Try to apply an exact rule
        outbound_types = collectAllOutboundTypes(entry.rule, exact_call_signature, node)
        if length(outbound_types) == 1
            entry.outbound_type = outbound_types[1]
            return entry
        elseif length(outbound_types) > 1
            error("There are multiple outbound type possibilities for schedule entry:\n$(entry)Inbound types: $(inbound_types)\nPlease specify a message type.")
        end

        # Try to apply an approximate rule
        call_signature = vcat(exact_call_signature, isdefined(entry, :approximation) ? Type{entry.approximation} : Any)
        outbound_types = collectAllOutboundTypes(entry.rule, call_signature, node)
        if length(outbound_types) == 1
            entry.outbound_type = outbound_types[1].parameters[1]
            entry.approximation = outbound_types[1].parameters[2]
            return entry
        elseif length(outbound_types) > 1
            error("There are multiple outbound type possibilities for schedule entry:\n$(entry)Inbound types: $(inbound_types)\nPlease specify a message type and if required also an approximation method.")
        else
            error("No calculation rule available for schedule entry:\n$(entry)Inbound types: $(inbound_types).")
        end
    end
end

function interfacesFacingWrapsOrBuffers(graph::FactorGraph=currentGraph();
                                        include_wraps=true,
                                        include_buffers=true)
    # Return a list of interfaces in graph that face a wrap or writebuffer.
    interfaces = Interface[]

    # Collect wrap facing interfaces
    if include_wraps
        for wrap in wraps(graph)
            push!(interfaces, wrap.tail.interfaces[1].partner)
            if isdefined(graph, :block_size)
                push!(interfaces, wrap.head.interfaces[1].partner)
            end
        end
    end

    # Collect write buffer facing interfaces
    if include_buffers
        for entry in keys(graph.write_buffers)
            if typeof(entry) == Interface
                push!(interfaces, entry)
            elseif typeof(entry) == Edge
                push!(interfaces, entry.head)
                push!(interfaces, entry.tail)
            end
        end
    end

    return interfaces
end

#######################################################
# Shared methods for algorithm preparation/compilation
#######################################################

function buildExecute!(entry::ScheduleEntry, inbound_arguments::Vector)
    # Construct the entry.execute function.
    # This function is called by the prepare methods of inference algorithms.

    # Get pointer to the outbound distribution
    outbound_dist = entry.node.interfaces[entry.outbound_interface_id].message.payload

    # Save the "compiled" message computation rule as an anomynous function in entry.execute
    if isdefined(entry, :approximation)
        entry.execute = ( () -> entry.rule(entry.node, Val{entry.outbound_interface_id}, outbound_dist, inbound_arguments..., entry.approximation) )
    else
        entry.execute = ( () -> entry.rule(entry.node, Val{entry.outbound_interface_id}, outbound_dist, inbound_arguments...) )
    end

    return entry
end

function injectParameters!{T<:ProbabilityDistribution}(destination::T, source::T)
    # Fill the parameters of a destination distribution with the copied parameters of the source

    for field in fieldnames(source)
        setfield!(destination, field, deepcopy(getfield(source, field)))
    end

    return destination
end