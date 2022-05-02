using .SampleChainsDynamicHMC
using Random

export sample

using ..Soss

using .SampleChainsDynamicHMC: DynamicHMCConfig

function sample(rng::AbstractRNG, 
    m::ConditionalModel,
    config::DynamicHMCConfig, 
    nsamples::Int=1000,
    nchains::Int=4)

    ℓ(x) = MeasureTheory.logdensityof(m, x)
    tr = TV.as(m)

    chains = newchain(rng, nchains, config, ℓ, tr)
    sample!(chains, nsamples - 1)
    return chains
end


function sample(
    m::ConditionalModel,
    config::DynamicHMCConfig, 
    nsamples::Int=1000,
    nchains::Int=4)

    sample(Random.GLOBAL_RNG, m, config, nsamples, nchains)
end
