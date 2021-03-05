using SampleChainsDynamicHMC
using Random

export sample

using ..Soss

function sample(rng::AbstractRNG, 
    ::Type{DynamicHMCChain}, 
    m::ConditionalModel,
    nsamples=1000,
    nchains=4)

    ℓ(x) = logdensity(m, x)
    tr = TransformVariables.as(m)

    chains = initialize!(rng, DynamicHMCChain, nchains, ℓ, tr)
    drawsamples!(chains, nsamples - 1)
    return chains
end


function sample(
    ::Type{DynamicHMCChain}, 
    m::ConditionalModel,
    nsamples=1000,
    nchains=4)

    sample(Random.GLOBAL_RNG, DynamicHMCChain, ConditionalModel, nsamples, nchains)
end
