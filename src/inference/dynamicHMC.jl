using LogDensityProblems,
      DynamicHMC,
      Statistics,
      ForwardDiff
import LogDensityProblems: ADgradient

export dynamicHMC

"""
    dynamicHMC(
        rng::AbstractRNG,
        m::ConditionalModel,
        _data,
        N::Int = 1000;
        method = logdensity,
        ad_backend = Val(:ForwardDiff),
        reporter = DynamicHMC.NoProgressReport(),
        kwargs...)


Draw `N` samples from the posterior distribution of parameters defined in Soss model `m`, conditional on `_data`. Samples are drawn using Hamiltonial Monte Carlo (HMC) from the `DynamicHMC.jl` package.

This function is essentially a wrapper around `DynamicHMC.mcmc_with_warmup()`. Arguments `reporter`, `ad_backend` [DynamicHMC docs here](https://tamaspapp.eu/DynamicHMC.jl/stable/interface/#DynamicHMC.mcmc_with_warmup))

## Arguments
* `rng`: Random number generator.
* `m`: Soss model.
* `_data`: `NamedTuple` of data to condition on.


## Keyword Arguments
*  `N = 1000`: Number of samples to draw.
*  `method = logdensity`: How to compute the log-density. Options are `logdensity` (delegates to `logdensity` of each component) or `codegen` (symbolic simplification and code generation).
*  `ad_backend = Val(:ForwardDiff)`: Automatic differentiation backend.
*  `reporter = DynamicHMC.NoProgressReport()`: Specify logging during sampling. Default: do not log progress.
*  `kwargs`: Additional keyword arguments passed to core sampling function `DynamicHMC.mcmc_with_warmup()`.


Returns an Array of `Namedtuple` of length `N`. Each entry in the array is a sample of parameters indexed by the parameter symbol.

## Example

```jldoctest
using StableRNGs
rng = StableRNG(42);

m = @model x begin
    β ~ Normal()
    yhat = β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], 2.0)
    end
end

x = randn(rng, 3);
truth = [-0.41, 1.21, 0.11];

post = dynamicHMC(rng, m(x=x), (y=truth,));
E_β = mean(getfield.(post, :β))

println("Posterior mean β: " * string(round(E_β, digits=2)))

# output
Posterior mean β: 0.25
```

"""
function dynamicHMC(
    rng::AbstractRNG,
    m::ConditionalModel,
    N::Int = 1000;
    # method = logdensityof,
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)

    M = getmoduletypencoding(m)

    ℓ = if haskey(kwargs, :ℓ)
        codegen(m; ℓ = kwargs[:ℓ])
    else 
        (a, o, pars) -> _logdensity_def(M, Model(m), a, o, pars)
    end

    _argvals = argvals(m)
    _obs = observations(m)

    logp(pars) = ℓ(_argvals, _obs, pars)

    t = as(m)
    P = LogDensityProblems.TransformedLogDensity(t, logp)
    ∇P = LogDensityProblems.ADgradient(ad_backend, P)

    results = DynamicHMC.mcmc_with_warmup(
        rng,
        ∇P,
        N;
        reporter = reporter
    )
    T = typeof(t(zeros(t.dimension)))

    x = TupleArray{T,1}(undef, N)

    for j in 1:N
        @inbounds x[j] = TV.transform(t, results.chain[j])
    end

    return x
    # samples = TransformVariables.transform.(t, results.chain)
    # return samples
end

function dynamicHMC(
    rng::AbstractRNG,
    m::ConditionalModel,
    ::Val{Inf};
    method = logdensity,
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)
    _data = m.obs
    ℓ(pars) = logdensity_def(m, merge(pars, _data), method)
    t = as(m, _data)
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

function dynamicHMC(m::ConditionalModel, args...; kwargs...)
    return dynamicHMC(Random.GLOBAL_RNG, m, args...; kwargs...)
end


# using ResumableFunctions

# export stream

# @resumable function stream(
#     rng::AbstractRNG,
#     f::typeof(dynamicHMC),
#     m::ConditionalModel,
#     _data::NamedTuple,
# )
#     t = as(m, _data)
#     (results, steps) = dynamicHMC(rng, m, _data, Val(Inf))
#     Q = results.final_warmup_state.Q
#     while true
#         Q, tree_stats = DynamicHMC.mcmc_next_step(steps, Q)
#         @yield (merge(t(Q.q), (_ℓ = Q.ℓq,)), tree_stats)
#     end
# end

# function stream(
#     f::typeof(dynamicHMC),
#     m::ConditionalModel,
#     _data::NamedTuple;
#     kwargs...,
# )
#     return stream(Random.GLOBAL_RNG, f, m, _data; kwargs...)
# end
