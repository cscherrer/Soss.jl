using TransformVariables,
      LogDensityProblems,
      DynamicHMC,
      Distributions,
      Statistics,
      StatsFuns,
      ForwardDiff
import LogDensityProblems: ADgradient

export dynamicHMC

"""
    dynamicHMC(
        rng::AbstractRNG,
        m::JointDistribution,
        _data,
        N::Int = 1000;
        method = logpdf,
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
*  `method = logpdf`: How to compute the log-density. Options are `logpdf` (delegates to `logpdf` of each component) or `codegen` (symbolic simplification and code generation).
*  `ad_backend = Val(:ForwardDiff)`: Automatic differentiation backend.
*  `reporter = DynamicHMC.NoProgressReport()`: Specify logging during sampling. Default: do not log progress.
*  `kwargs`: Additional keyword arguments passed to core sampling function `DynamicHMC.mcmc_with_warmup()`.


Returns an Array of `Namedtuple` of length `N`. Each entry in the array is a sample of parameters indexed by the parameter symbol.

## Example

```jldoctest

using Random
Random.seed!(42);
rng = MersenneTwister(42);

m = @model x begin
    β ~ Normal()
    yhat = β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], 2.0)
    end
end

x = randn(50);
truth = rand(m(x=x));

post = dynamicHMC(rng, m(x=x), (y=truth.y,));
E_β = mean(getfield.(post, :β))

println("true β: " * string(round(truth.β, digits=2)))
println("Posterior mean β: " * string(round(E_β, digits=2)))

# output
true β: 0.3
Posterior mean β: 0.47
```

"""
function dynamicHMC(
    rng::AbstractRNG,
    m::JointDistribution,
    _data,
    N::Int = 1000;
    method = logpdf,
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)
    ℓ(pars) = logpdf(m, merge(pars, _data), method)
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
    method = logpdf,
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)
    ℓ(pars) = logpdf(m, merge(pars, _data), method)
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
