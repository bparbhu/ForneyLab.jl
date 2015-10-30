#####################
# Unit tests
#####################

facts("FixedGainNode unit tests") do
    context("FixedGainNode() should initialize a FixedGainNode with 2 interfaces") do
        FactorGraph()
        FixedGainNode([1.0], id=:node)
        @fact typeof(n(:node)) --> FixedGainNode
        @fact length(n(:node).interfaces) --> 2
        @fact n(:node).i[:in] --> n(:node).interfaces[1]
        @fact n(:node).i[:out] --> n(:node).interfaces[2]
        @fact typeof(n(:node).A) <: Array --> true
        @fact length(size(n(:node).A)) --> 2 # A should always be a matrix
    end

    context("FixedGainNode should provide sumProduct! for DeltaDistribution{Float64}") do
        # Backward message
        validateOutboundMessage(FixedGainNode(2.0),
                                1,
                                [nothing, Message(DeltaDistribution(3.0))],
                                DeltaDistribution(1.5))
        # Forward message
        validateOutboundMessage(FixedGainNode(2.0),
                                2,
                                [Message(DeltaDistribution(3.0)), nothing],
                                DeltaDistribution(6.0))
    end

    context("FixedGainNode should provide sumProduct! for MvDeltaDistribution{Float64}") do
        # Backward message
        A = [1.0 0.5; -0.5 2.0]
        validateOutboundMessage(FixedGainNode(A),
                                1,
                                [nothing, Message(MvDeltaDistribution([30.0, 10.0]))],
                                MvDeltaDistribution(inv(A)*[30.0, 10.0]))
        # Forward message
        validateOutboundMessage(FixedGainNode(A),
                                2,
                                [Message(MvDeltaDistribution([30.0, 10.0])), nothing],
                                MvDeltaDistribution(A*[30.0, 10.0]))
    end

    context("FixedGainNode should provide sumProduct! for GaussianDistribution") do
        context("(m,V) parametrization") do
            # Backward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    1,
                                    [nothing, Message(GaussianDistribution(m=3.0, V=5.0))],
                                    GaussianDistribution(m=1.5, V=1.25))
            # Forward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    2,
                                    [Message(GaussianDistribution(m=3.0, V=5.0)), nothing],
                                    GaussianDistribution(m=6.0, V=20.0))
        end
        context("(m,W) parametrization") do
            # Backward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    1,
                                    [nothing, Message(GaussianDistribution(m=3.0, W=2.0))],
                                    GaussianDistribution(m=1.5, W=8.0))
            # Forward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    2,
                                    [Message(GaussianDistribution(m=3.0, W=2.0)), nothing],
                                    GaussianDistribution(m=6.0, W=0.5))
        end
        context("(xi,W) parametrization") do
            # Backward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    1,
                                    [nothing, Message(GaussianDistribution(xi=6.0, W=2.0))],
                                    GaussianDistribution(xi=12.0, W=8.0))
            # Forward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    2,
                                    [Message(GaussianDistribution(xi=6.0, W=2.0)), nothing],
                                    GaussianDistribution(xi=3.0, W=0.5))
        end
        context("Improper distributions") do
            # Backward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    1,
                                    [nothing, Message(GaussianDistribution(m=3.0, V=-5.0))],
                                    GaussianDistribution(m=1.5, V=-1.25))
            # Forward message
            validateOutboundMessage(FixedGainNode(2.0),
                                    2,
                                    [Message(GaussianDistribution(m=3.0, V=-5.0)), nothing],
                                    GaussianDistribution(m=6.0, V=-20.0))
        end
    end

    context("FixedGainNode should provide sumProduct! for MvGaussianDistribution") do
        # The following tests on the update rules correspond to nodes 3 and 4 from Table 4.1 in:
        # Korl, Sascha. “A Factor Graph Approach to Signal Modelling, System Identification and Filtering.” Hartung-Gorre, 2005.
        A = [   3.0 2.0 1.0;
                2.0 3.0 2.0;
                1.0 2.0 3.0]
        context("(m,V) parametrization") do
            mean = collect(1.0:3.0)
            variance = [4.0 3.0 2.0;
                        3.0 4.0 3.0;
                        2.0 3.0 4.0]
            # Backward message
            validateOutboundMessage(FixedGainNode(A),
                                    1,
                                    [nothing, Message(MvGaussianDistribution(m=mean, V=variance))],
                                    MvGaussianDistribution(m=inv(A) * mean, V=inv(A) * variance * inv(A)'))
            # Forward message
            validateOutboundMessage(FixedGainNode(A),
                                    2,
                                    [Message(MvGaussianDistribution(m=mean, V=variance)), nothing],
                                    MvGaussianDistribution(m=A * mean, V=A * variance * A'))
        end
        context("(m,W) parametrization") do
            mean = collect(1.0:3.0)
            precision = inv([   4.0 3.0 2.0;
                                3.0 4.0 3.0;
                                2.0 3.0 4.0])
            # Backward message
            validateOutboundMessage(FixedGainNode(A),
                                    1,
                                    [nothing, Message(MvGaussianDistribution(m=mean, W=precision))],
                                    MvGaussianDistribution(m=inv(A) * mean, W=A' * precision * A))
            # Forward message
            validateOutboundMessage(FixedGainNode(A),
                                    2,
                                    [Message(MvGaussianDistribution(m=mean, W=precision)), nothing],
                                    MvGaussianDistribution(m=A * mean, W=inv(A)' * precision * inv(A)))
        end
    end
end
