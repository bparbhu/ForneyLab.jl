facts("Marginal calculation integration tests") do
    context("Marginal calculation for two GammaDistributions") do
        @fact calculateMarginal(GammaDistribution(a=1.0, b=2.0), GammaDistribution(a=3.0, b=4.0)) => GammaDistribution(a=3.0, b=6.0)
    end

    context("Marginal calculation for two InverseGammaDistributions") do
        @fact calculateMarginal(InverseGammaDistribution(a=1.0, b=2.0), InverseGammaDistribution(a=3.0, b=4.0)) => InverseGammaDistribution(a=5.0, b=6.0)
    end

    context("Marginal calculation for two GaussianDistributions") do
        @fact calculateMarginal(GaussianDistribution(xi=1.0, W=2.0), GaussianDistribution(xi=3.0, W=4.0)) => GaussianDistribution(xi=4.0, W=6.0)
    end

    context("Marginal calculation for the combination of a Gaussian and student's t-distribution") do
        @fact calculateMarginal(GaussianDistribution(m=0.0, W=1.0), StudentsTDistribution(m=0.0, W=1.0, nu=1.0)) => GaussianDistribution(m=0.0, W=3.0)
        @fact calculateMarginal(StudentsTDistribution(m=0.0, W=1.0, nu=1.0), GaussianDistribution(m=0.0, W=1.0)) => GaussianDistribution(m=0.0, W=3.0)
    end

    context("Marginal calculation for naively factorized GaussianNode") do
        (node, edges) = initializeGaussianNode(y_type=Float64)
        graph = getCurrentGraph()
        factorizeMeanField!(graph)
        
        # Presetting uninformative marginals
        subgraph1 = getSubgraph(graph, edges[1])
        graph.approximate_marginals[(node, subgraph1)] = uninformative(GaussianDistribution)
        subgraph2 = getSubgraph(graph, edges[2])
        graph.approximate_marginals[(node, subgraph2)] = uninformative(GammaDistribution)
        subgraph3 = getSubgraph(graph, edges[3])
        graph.approximate_marginals[(node, subgraph3)] = uninformative(Float64)
        
        # Univariate marginal
        calculateMarginal!(node, subgraph1, graph)
        @fact graph.approximate_marginals[(node, subgraph1)] => GaussianDistribution(W=2.0, xi=0.0)
        # Univariate marginal
        calculateMarginal!(node, subgraph2, graph)
        @fact graph.approximate_marginals[(node, subgraph2)] => GammaDistribution(a=1.0, b=2.0)
        # Univariate marginal
        calculateMarginal!(node, subgraph3, graph)
        @fact graph.approximate_marginals[(node, subgraph3)] => 1.0
    end
    
    context("Marginal calculation for the structurally factorized GaussianNode") do
        (node, edges) = initializeGaussianNode(y_type=GaussianDistribution)
        graph = getCurrentGraph()
        factorize!(Set{Edge}([edges[3]]))
        
        # Presetting uninformative marginals
        graph.approximate_marginals[(node, graph.factorization[1])] = uninformative(NormalGammaDistribution)
        graph.approximate_marginals[(node, graph.factorization[2])] = uninformative(GaussianDistribution)
        
        # Joint marginal
        subgraph = graph.factorization[1]
        calculateMarginal!(node, subgraph, graph)
        @fact graph.approximate_marginals[(node, subgraph)] => NormalGammaDistribution(m=0.0, beta=10000.0, a=1.5, b=501.0)
        # Univariate marginal
        subgraph = graph.factorization[2]
        calculateMarginal!(node, subgraph, graph)
        @fact graph.approximate_marginals[(node, subgraph)] => GaussianDistribution(W=1.001, xi=0.0)
    end
end