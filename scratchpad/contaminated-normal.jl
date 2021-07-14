using Soss

contaminatedNormal = @model begin
    p ~ Uniform()
    x ~ Normal()
    ε ~ Normal(σ=10)
    return p<0.1 ? x : ε
end

m = @model prior begin
    x ~ prior()
    y ~ Binomial(n=10, logitp=x) 
    return y
end

y = rand(m(prior=contaminatedNormal))

using SampleChainsDynamicHMC

sample(DynamicHMCChain, m(prior=contaminatedNormal) | (;y=4))
