using SampleChainsDynamicHMC
using Random

export sample

using ..Soss

function sample(rng::AbstractRNG, 
    ::Type{DynamicHMCChain}, 
    m::ConditionalModel,
    nsamples::Int=1000,
    nchains::Int=4)

    ℓ(x) = logdensity(m, x)
    tr = xform(m)

    chains = initialize!(rng, nchains, DynamicHMCChain, ℓ, tr)
    drawsamples!(chains, nsamples - 1)
    return chains
end


function sample(
    ::Type{DynamicHMCChain}, 
    m::ConditionalModel,
    nsamples::Int=1000,
    nchains::Int=4)

    sample(Random.GLOBAL_RNG, DynamicHMCChain, m, nsamples, nchains)
end
