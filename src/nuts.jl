using TransformVariables, LogDensityProblems, DynamicHMC, MCMCDiagnostics, Parameters,
    Distributions, Statistics, StatsFuns, ForwardDiff

using Random

export nuts

import Flux
function nuts(m :: BoundModel{A,B}, _data) where {A,B}
    rng = MersenneTwister()
    ℓ(pars) = logpdf(m, merge(pars, _data))

    t = xform(m,_data)
    P = TransformedLogDensity(t, ℓ)
    ∇P = ADgradient(Val(:Flux), P)
    results = mcmc_with_warmup(MersenneTwister(), ∇P, 1000; reporter=DynamicHMC.NoProgressReport());
    samples = TransformVariables.transform.(parent(∇P).transformation, results.chain)
    # ... here you may want to return: samples, results.chain, results.tree_statistics,
    #     results.κ, results.ϵ in your container type
end
