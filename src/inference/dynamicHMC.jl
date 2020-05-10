using TransformVariables,
      LogDensityProblems,
      DynamicHMC,
      Distributions,
      Statistics,
      StatsFuns,
      ForwardDiff
import LogDensityProblems: ADgradient

export dynamicHMC

function dynamicHMC(
    rng::AbstractRNG,
    m::JointDistribution,
    _data,
    N::Int = 1000;
    method = logdensity,
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)
    ℓ(pars) = logdensity(m, merge(pars, _data), method)
    t = xform(m, _data)
    P = LogDensityProblems.TransformedLogDensity(t, ℓ)
    ∇P = LogDensityProblems.ADgradient(ad_backend, P)

    results = DynamicHMC.mcmc_with_warmup(
        rng,
        ∇P,
        N;
        reporter = reporter,
        kwargs...,
    )
    samples = TransformVariables.transform.(t, results.chain)
    return samples
end

function dynamicHMC(
    rng::AbstractRNG,
    m::JointDistribution,
    _data,
    ::Val{Inf};
    method = logdensity,
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)
    ℓ(pars) = logdensity(m, merge(pars, _data), method)
    t = xform(m, _data)
    P = LogDensityProblems.TransformedLogDensity(t, ℓ)
    ∇P = LogDensityProblems.ADgradient(ad_backend, P)

    results = DynamicHMC.mcmc_keep_warmup(
        rng,
        ∇P,
        0;
        reporter = reporter,
        kwargs...,
    )
    steps = DynamicHMC.mcmc_steps(
        results.sampling_logdensity,
        results.final_warmup_state,
    )
    return results, steps
end

function dynamicHMC(m::JointDistribution, args...; kwargs...)
    return dynamicHMC(Random.GLOBAL_RNG, m, args...; kwargs...)
end


using ResumableFunctions

export stream

@resumable function stream(
    rng::AbstractRNG,
    f::typeof(dynamicHMC),
    m::JointDistribution,
    _data::NamedTuple,
)
    t = xform(m, _data)
    (results, steps) = dynamicHMC(rng, m, _data, Val(Inf))
    Q = results.final_warmup_state.Q
    while true
        Q, tree_stats = DynamicHMC.mcmc_next_step(steps, Q)
        @yield (merge(t(Q.q), (_ℓ = Q.ℓq,)), tree_stats)
    end
end

function stream(
    f::typeof(dynamicHMC),
    m::JointDistribution,
    _data::NamedTuple;
    kwargs...,
)
    return stream(Random.GLOBAL_RNG, f, m, _data; kwargs...)
end
