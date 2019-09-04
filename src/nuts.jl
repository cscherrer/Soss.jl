using TransformVariables, LogDensityProblems, DynamicHMC, MCMCDiagnostics, Parameters,
    Distributions, Statistics, StatsFuns, ForwardDiff

# struct NUTS_result{T}
#     chain::Vector{NUTS_Transition{Vector{Float64},Float64}}
#     transformation
#     samples::Vector{T}
#     tuning
# end

# Base.show(io::IO, n::NUTS_result) = begin
#     println(io, "NUTS_result with samples:")
#     println(IOContext(io, :limit => true, :compact => true), n.samples)
# end
using Random

export nuts

import Flux
function nuts(m :: Model{A,B,D}, args, data) where {A,B,D}
    rng = MersenneTwister()
    ℓ(pars) = logdensity(m, args, data, pars)

    t = xform(m,args)
    P = TransformedLogDensity(t, ℓ)
    ∇P = ADgradient(Val(:Flux), P)
    results = mcmc_with_warmup(MersenneTwister(), ∇P, 1000);
    samples = TransformVariables.transform.(parent(∇P).transformation, results.chain)
    # ... here you may want to return: samples, results.chain, results.tree_statistics,
    #     results.κ, results.ϵ in your container type
end
