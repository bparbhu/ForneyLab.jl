# User guide
This user guide outlines the usage of ForneyLab for solving inference problems. The main content is divided in three parts:
- [Specifying a model](@ref)
- [Generating an algorithm](@ref)
- [Executing an algorithm](@ref)

For installation instructions see the [Getting started](@ref) page. To import ForneyLab into the active Julia session run  

```@example 1
using ForneyLab
```

## Specifying a model
Probabilistic models incorporate the element of randomness to describe an event or phenomenon. They do this by using random variables and probability distributions. These models can be represented diagrammatically using probabilistic graphical models (PGMs). A factor graph is a type of PGM that is well suited to cast inference tasks in terms of graphical manipulations.

### Creating a new factor graph
Factor graphs are represented by the `FactorGraph` composite type (struct). To instantiate a new (empty) factor graph we use its constructor function that takes no arguments
```@example 1
g = FactorGraph()
nothing # hide
```

ForneyLab keeps track of an *active* factor graph at all times. Future operations on the graph, such as adding variables or nodes, affect the active graph. The call to `FactorGraph()` creates a new instance of a factor graph and registers it as the active graph.

To get the active graph run
```@example 1
fg = currentGraph()
nothing # hide
```

To set the active graph run
```@example 1
setCurrentGraph(g)
nothing # hide
```

### Adding random variables (edges)
Random variables are represented as edges on Forney-style factor graphs. You can add a random variable to the active factor graph by instantiating the `Variable` composite type. The constructor function takes an `id` of type `Symbol` as argument. For example, running
```@example 1
x = Variable(id=:x)
nothing # hide
```
associates the variable `x` to an edge of the active factor graph.

Alternatively, the `@RV` macro can be used for the same purpose in a more compact form. Executing the following line has the same effect as the previous one.
```@example 1
@RV x
nothing # hide
```
By default, the `@RV` macro uses the variable's name to create a Julia `Symbol` that is assigned to the `id` field of the `Variable` object (`:x` in this example). However, if this id value has already been assigned to a variable in the factor graph, then ForneyLab will create a default id of the form `:variable_x`, where `x` is a number that increments. In case you want to provide a custom `id`, the `@RV` macro accepts an optional keyword argument between square brackets that allows this. For example,
```@example 1
@RV [id=:my_id] x
nothing # hide
```
adds the variable `x` to the active graph and assigns the `:my_id` symbol to its `id` field. Later we will see that this is useful once we start visualizing the factor graph.

### Adding factor nodes
Factor nodes are used to define the relationship between different random variables. They assign probability distributions to a random variable as a function of other variables. See [Factor nodes](@ref) for a complete list of the available factor nodes in ForneyLab.

We can assign a probability distribution to a random variable using the `~` operator together with the `@RV` macro. For example, to create a Gaussian distributed random variable `y`, where its mean and variance are controlled by the random variables `m` and `v` respectively, we could run
```@example 1
@RV m
@RV v
@RV y ~ GaussianMeanVariance(m, v)
nothing # hide
```

### Visualizing a factor graph
Factor graphs can be visualized using the `draw` function. It takes a `FactorGraph` object as argument. Let's visualize the factor graph that we defined in the previous section.
```@example 1
ForneyLab.draw(g)
```
Edges that are not connected to any factor node are not drawn.

### Clamping
Suppose we know that the variance of the random variable `y`, of the previous model, is fixed to a certain value. ForneyLab provides a special factor node to impose this kind of constraint called a `Clamp`. Clamp factor nodes can be implicitly defined by using literals like in the following example
```@example 1
g = FactorGraph() # create a new factor graph
@RV m
@RV y ~ GaussianMeanVariance(m, 1.0)
ForneyLab.draw(g)
```
Here, the literal `1.0` that is passed as the second argument to `GaussianMeanVariance` function creates a clamp node implicitly. Clamp factor nodes are visualized with a gray background.

Alternatively, if you want to assign a custom `id` to a `Clamp` factor node, then you have to instantiate them explicitly using its constructor function, i.e.
```@example 1
g = FactorGraph() # create a new factor graph
@RV m
@RV v ~ Clamp(1.0)
@RV y ~ GaussianMeanVariance(m, v)
ForneyLab.draw(g)
```

### Placeholders
Placeholders are a kind of `Clamp` factor nodes that act as entry points for data. They associate a given random variable with a buffer through which data is fed at a later point. This buffer has an `id`, a dimensionality and a data type. Placeholders are created with the `placeholder` function. Suppose that we want to feed an array of one-dimensional floating-point data to the `y` random variable of the previous model. We would then need to define `y` as a placeholder as follows.
```@example 1
g = FactorGraph() # create a new factor graph
@RV m
@RV v ~ Clamp(1.0)
@RV y ~ GaussianMeanVariance(m, v)
placeholder(y, :y)
ForneyLab.draw(g)
```
Placeholders default to one-dimensional floating-point data. In case we want to override this with, for example, 3-dimensional integer data, we would need to specify the `dims` and `datatpye` parameters of the `placeholder` function as follows
```julia
placeholder(y, :y, dims=(3,), datatype=Int)
```

In the previous example, we first created the random variable `y` and then marked it as a placeholder. There is, however, a shorthand version to perform these two steps in one. The syntax consists of calling a `placeholder` method that takes an id `Symbol` as argument and returns the new random variable. Here is an example:
```@example 1
x = placeholder(:x)
nothing # hide
```
where `x` is now a random variable linked to a placeholder with id `:x`.

In section [Executing an algorithm](@ref) we will see how the data is fed to the placeholders.


### Overloaded operators
ForneyLab supports the use of the `+`, `-` and `*` operators between random variables that have certain types of probability distributions. This is known as *operator overloading*. These operators are represented as deterministic factor nodes in ForneyLab. As an example, a two-component Gaussian mixture can be defined as follows  

```@example 1
g = FactorGraph() # create a new factor graph
@RV x ~ GaussianMeanVariance(0.0, 1.0)
@RV y ~ GaussianMeanVariance(2.0, 3.0)
@RV z = x + y
placeholder(z, :z)
ForneyLab.draw(g)
```

### Online vs. offline learning
Online learning refers to a procedure where observations are processed as soon as they become available. In the context of factor graphs this means that observations need to be fed to the placeholders and processed one at a time. In a Bayesian setting, this reduces to the application of Bayes rule in a recursive fashion, i.e. the posterior distribution for a given random variable, becomes the prior for the next processing step. Since we are feeding one observation at each time step, the factor graph will have *one* placeholder for every observed variable. All of the factor graphs that we have seen so far were specified to process data in this fashion.

Let's take a look at an example in order to contrast it with its offline counterpart. In this simple example, the mean `x` of a Gaussian distributed random variable `y` is modelled by another Gaussian distribution with hyperparameters `m` and `v`. The variance of `y` is assumed to be known.
```@example 1
g = FactorGraph() # create a new factor graph
m = placeholder(:m)
v = placeholder(:v)
@RV x ~ GaussianMeanVariance(m, v)
@RV y ~ GaussianMeanVariance(x, 1.0)
placeholder(y, :y)
ForneyLab.draw(g)
```
As we have seen in previous examples, there is one placeholder linked to the observed variable `y` that accepts one observation at a time. Perhaps what is less obvious is that the hyperparameters `m` and `v` are also defined as placeholders. The reason for this is that we will use them to input our current (prior) belief about `x` for every observation that is processed. In section [Executing an algorithm](@ref) we will elaborate more on this.

Offline learning, on the other hand, involves feeding and processing a batch of `N` observations (typically all available observations) in a single step. This translates into a factor graph that has one placeholder linked to a random variable for *each* sample in the batch. We can specify this type of models using a `for` loop like in the following example.
```@example 1
g = FactorGraph()   # create a new factor graph
N = 3               # number of observations
y = Vector{Variable}(undef, N)
@RV x ~ GaussianMeanVariance(0.0, 1.0)
for i = 1:N
    @RV y[i] ~ GaussianMeanVariance(x, 1.0)
    placeholder(y[i], :y, index=i)
end
ForneyLab.draw(g)
```
The important thing to note here is that we need an extra array of `N` observed random variables where each of them is linked to a dedicated index of the placeholder's buffer. This buffer can be thought of as an `N` dimensional array of `Clamp` factor nodes. We achieve this link by means of the `index` parameter of the `placeholder` function.

In section [Executing an algorithm](@ref) we will see examples of how the data is fed to the placeholders in each of these two scenarios.

## Generating an algorithm
ForneyLab supports code generation for three different types of message-passing algorithms:
- [Belief propagation](https://en.wikipedia.org/wiki/Belief_propagation)
- [Variational message passing](https://en.wikipedia.org/wiki/Variational_message_passing)
- [Expectation propagation](https://en.wikipedia.org/wiki/Expectation_propagation)

Whereas belief propagation computes exact inference for the random variables of interest, variational message passing (VMP) and expectation propagation (EP) algorithms are approximation methods that can be applied to a larger range of models.

### Belief propagation
The way to instruct ForneyLab to generate a belief propagation algorithm (also known as a sum-product algorithm) is by using the `sumProductAlgorithm` function. This function takes as argument(s) the random variable(s) for which we want to infer the posterior distribution. As an example, consider the following hierarchical model in which the mean of a Gaussian distribution is represented by another Gaussian distribution whose mean is modelled by another Gaussian distribution.  
```@example 1
g = FactorGraph() # create a new factor graph
@RV m2 ~ GaussianMeanVariance(0.0, 1.0)
@RV m1 ~ GaussianMeanVariance(m2, 1.0)
@RV y ~ GaussianMeanVariance(m1, 1.0)
placeholder(y, :y)
ForneyLab.draw(g)
```
If we were only interested in inferring the posterior distribution of `m1` then we would run
```@example 1
algorithm_string = sumProductAlgorithm(m1)
nothing # hide
```
On the other hand, if we were interested in the posterior distributions of both `m1` and `m2` we would then need to pass them as elements of an array, i.e.
```@example 1
algorithm_string = sumProductAlgorithm([m1, m2])
nothing # hide
```

Note that the message-passing algorithm returned by the `sumProductAlgorithm` function is a `String` that contains the definition of a Julia function. In order to be able to execute this function, we first need to parse this string as Julia expression to then evaluate it in the current scope that the program is running on. This can be done as follows
```@example 1
algorithm_expr = Meta.parse(algorithm_string)
nothing # hide
```
```julia
:(function step!(data::Dict, marginals::Dict=Dict(), messages::Vector{Message}=Array{Message}(undef, 4))
      #= none:3 =#
      messages[1] = ruleSPGaussianMeanVarianceOutNPP(nothing, Message(Univariate, PointMass, m=0.0), Message(Univariate, PointMass, m=1.0))
      #= none:4 =#
      messages[2] = ruleSPGaussianMeanVarianceOutNGP(nothing, messages[1], Message(Univariate, PointMass, m=1.0))
      #= none:5 =#
      messages[3] = ruleSPGaussianMeanVarianceMPNP(Message(Univariate, PointMass, m=data[:y]), nothing, Message(Univariate, PointMass, m=1.0))
      #= none:6 =#
      messages[4] = ruleSPGaussianMeanVarianceMGNP(messages[3], nothing, Message(Univariate, PointMass, m=1.0))
      #= none:8 =#
      marginals[:m1] = (messages[2]).dist * (messages[3]).dist
      #= none:9 =#
      marginals[:m2] = (messages[1]).dist * (messages[4]).dist
      #= none:11 =#
      return marginals
  end)
```

```@example 1
eval(algorithm_expr)
```

At this point a new function named `step!` becomes available in the current scope. This function contains a message-passing algorithm that infers both `m1` and `m2` given one or more `y` observations. In the section [Executing an algorithm](@ref) we will see how this function is used.

### Variational message passing
Variational message passing (VMP) algorithms are generated much in the same way as the belief propagation algorithm we saw in the previous section. There is a major difference though: for VMP algorithm generation we need to define the factorization properties of our approximate distribution. A common approach is to assume that all random variables of the model factorize with respect to each other. This is known as the *mean field* assumption. In ForneyLab, the specification of such factorization properties is defined using the `RecognitionFactorization` composite type. Let's take a look at a simple example to see how it is used. In this model we want to learn the mean and variance of a Gaussian distribution, where the former is modelled with a Gaussian distribution and the latter with a Gamma.
```@example 1
g = FactorGraph() # create a new factor graph
@RV m ~ GaussianMeanVariance(0, 10)
@RV w ~ Gamma(0.1, 0.1)
@RV y ~ GaussianMeanPrecision(m, w)
placeholder(y, :y)
draw(g)
```
The construct of the `RecognitionFactorization` composite type takes the random variables of interest as arguments and one final argument consisting of an array of symbols used to identify each of these random variables. Here is an example of how to use this construct for the previous model where we want to infer `m` and `w`.
```@example 1
q = RecognitionFactorization(m, w, ids=[:M, :W])
nothing # hide
```
This recognition factorization constraint that we introduce to guarantee tractability of the approximate distribution has a graphical interpretation. We can view this constraint as a division of the factor graph into a number of different subgraphs, each corresponding to a different factor in the recognition factorization. Minimization of the free energy is performed by iterating over each subgraph in order to update the posterior marginal corresponding to the current factor which depends on messages coming from the other subgraphs. This iteration is repeated until either the free energy converges to a certain value or the posterior marginals of each factor stop changing. We can use the `ids` passed to the `RecognitionFactorization` function to visualize their corresponding subgraphs, as shown below.   
```@example 1
ForneyLab.draw(q.recognition_factors[:M])
```
```@example 1
ForneyLab.draw(q.recognition_factors[:W])
```
Generating the VMP algorithm follows the same procedure that we saw for the belief propagation algorithm. In this case, however, the resulting algorithm will consist of a set of step functions, one for each recognition factor, that need to be executed iteratively until convergence.
```@example 1
# Generate variational update algorithms for each recognition factor
algo = variationalAlgorithm(q)
eval(Meta.parse(algo))
nothing # hide
```
```julia
Meta.parse(algo) = quote
    #= none:3 =#
    function stepM!(data::Dict, marginals::Dict=Dict(), messages::Vector{Message}=Array{Message}(undef, 2))
        #= none:5 =#
        messages[1] = ruleVBGaussianMeanVarianceOut(nothing, ProbabilityDistribution(Univariate, PointMass, m=0), ProbabilityDistribution(Univariate, PointMass, m=10))
        #= none:6 =#
        messages[2] = ruleVBGaussianMeanPrecisionM(ProbabilityDistribution(Univariate, PointMass, m=data[:y]), nothing, marginals[:w])
        #= none:8 =#
        marginals[:m] = (messages[1]).dist * (messages[2]).dist
        #= none:10 =#
        return marginals
    end
    #= none:14 =#
    function stepW!(data::Dict, marginals::Dict=Dict(), messages::Vector{Message}=Array{Message}(undef, 2))
        #= none:16 =#
        messages[1] = ruleVBGammaOut(nothing, ProbabilityDistribution(Univariate, PointMass, m=0.1), ProbabilityDistribution(Univariate, PointMass, m=0.1))
        #= none:17 =#
        messages[2] = ruleVBGaussianMeanPrecisionW(ProbabilityDistribution(Univariate, PointMass, m=data[:y]), marginals[:m], nothing)
        #= none:19 =#
        marginals[:w] = (messages[1]).dist * (messages[2]).dist
        #= none:21 =#
        return marginals
    end
end
```

#### Computing free energy
VMP inference boils down to finding the member of a family of tractable probability distributions that is closest in KL divergence to an intractable posterior distribution. This is achieved by minimizing a quantity known as *free energy*. ForneyLab provides the function `freeEnergyAlgorithm` which generates an algorithm that can be used to evaluate this quantity. This function takes an object of type `RecognitionFactorization` as argument. Free energy is particularly useful to test for convergence of the VMP iterative procedure. Here is an example that generates, parses and evaluates this algorithm.
```julia
fe_algorithm = freeEnergyAlgorithm(q)
eval(Meta.parse(fe_algorithm));
```

## Executing an algorithm
In section [Specifying a model](@ref) we introduced two main ways to learn from data, namely in an online and in an offline setting. We saw that the structure of the factor graph is different in each of these settings. In this section we will demonstrate how to feed data to an algorithm in both an online and an offline setting. We will use the same examples from section [Online vs. offline learning](@ref).

### Online learning
For convenience, let's reproduce the model specification for the problem of estimating the mean `x` of a Gaussian distributed random variable `y`, where `x` is modelled using another Gaussian distribution with hyperparameters `m` and `v`. Let's also generate a belief propagation algorithm for this inference problem like we have seen before.
```@example 1
g = FactorGraph() # create a new factor graph
m = placeholder(:m)
v = placeholder(:v)
@RV x ~ GaussianMeanVariance(m, v)
@RV y ~ GaussianMeanVariance(x, 1.0)
placeholder(y, :y)
eval(Meta.parse(sumProductAlgorithm(x))) # generate, parse and evaluate the algorithm
nothing # hide
```
In order to execute this algorithm we first have to specify a prior for `x`. This is done by choosing some initial values for the hyperparameters `m` and `v`. In each processing step, the algorithm expects an observation and the current belief about `x`, i.e. the prior. We pass this information as elements of a `data` dictionary where the keys are the `id`s of their corresponding placeholders. The algorithm performs inference and returns the results inside a different dictionary (which we call `marginals` in the following script). In the next iteration, we repeat this process by feeding the algorithm with the next observation in the sequence and the posterior distribution of `x` that we obtained in the previous processing step. In other words, the current posterior becomes the prior for the next processing step. Let's illustrate this using an example where we will first generate a synthetic dataset by sampling observations from a Gaussian distribution that has a mean of 5.
```@example 1
using Plots, LaTeXStrings; theme(:default) ;
pyplot(fillalpha=0.3, leg=false, xlabel=L"x", ylabel=L"p(x|D)", yticks=nothing)

N = 50                      # number of samples
dataset = randn(N) .+ 5     # sample N observations from a Gaussian with m=5 and v=1

normal(μ, σ²) = x -> (1/(sqrt(2π*σ²))) * exp(-(x - μ)^2 / (2*σ²)) # to plot results

m_prior = 0.0   # initialize hyperparameter m
v_prior = 10    # initialize hyperparameter v

marginals = Dict()  # this is where the algorithm stores the results

anim = @animate for i in 1:N
    data = Dict(:y => dataset[i],
                :m => m_prior,
                :v => v_prior)

    plot(-10:0.01:10, normal(m_prior, v_prior), fill=true)

    step!(data, marginals) # feed in prior and data points 1 at a time

    global m_prior = mean(marginals[:x]) # today's posterior is tomorrow's prior
    global v_prior = var(marginals[:x])  # today's posterior is tomorrow's prior
end
nothing # hide
```
![Online learning](./assets/belief-propagation-online.gif)

As we process more samples, our belief about the possible values of `m` becomes more confident.

### Offline learning
Executing an algorithm in an offline fashion is much simpler than in the online case. Let's reproduce the model specification of the previous example in an offline setting (also shown in [Online vs. offline learning](@ref).)
```@example 1
g = FactorGraph()   # create a new factor graph
N = 30              # number of observations
y = Vector{Variable}(undef, N)
@RV x ~ GaussianMeanVariance(0.0, 1.0)
for i = 1:N
    @RV y[i] ~ GaussianMeanVariance(x, 1.0)
    placeholder(y[i], :y, index=i)
end
eval(Meta.parse(sumProductAlgorithm(x))) # generate, parse and evaluate the algorithm
nothing # hide
```
Since we have a placeholder linked to each observation in the sequence, we can process the complete dataset in one step. To do so, we first need to create a dictionary having the complete dataset array as its single element. We then need to pass this dictionary to the `step!` function which, in contrast with the online counterpart, we only need to call once.
```@example 1
data = Dict(:y => dataset)
marginals = step!(data) # Run the algorithm
plot(-10:0.01:10, normal(mean(marginals[:x]), var(marginals[:x])), fill=true)
```

!!! note
    Batch processing does not perform well with large datasets at the moment. We are working on this issue.
