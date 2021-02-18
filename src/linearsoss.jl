

using Soss
using NestedTuples

using TransformVariables,
      LogDensityProblems,
      DynamicHMC,
      Statistics,
      ForwardDiff
import LogDensityProblems: ADgradient
using LinearAlgebra

function loglik(X,y) 
    (N,k) = size(X)
    yᵗy = y' * y
    yᵗX = y' * X
    XᵗX = X' * X
    ∑X = sum(X; dims=1)
    ∑y = sum(y)

    function f(α, β, σ)
        # If α==0 this would be
        # -N * log(σ) - 0.5/σ^2 * (yᵗy - 2 * yᵗX * β + β' * XᵗX * β)
        linear = α * ∑y + dot(yᵗX, β)
        quadratic = N * α^2 .+ (2α * dot(∑X, β) + β' * XᵗX * β)

        -N * log(σ) - 0.5/σ^2 * (yᵗy - 2 * linear + quadratic)
    end 
    return f
end

function makelogp(X, y, pr)
    k = size(X,2)
    ll = loglik(X,y)
    logp(pars) = ll(pars.α, pars.β, pars.σ) + logdensity(pr(k=k), pars)
end

function bayeslm(
    rng::AbstractRNG,
    X,
    y,
    pr, 
    N::Int = 1000;
    ad_backend = Val(:ForwardDiff),
    reporter = DynamicHMC.NoProgressReport(),
    kwargs...,
)
    logp = makelogp(X, y, pr)
    t = xform(pr(k=size(X,2)))
    P = LogDensityProblems.TransformedLogDensity(t, logp)
    ∇P = LogDensityProblems.ADgradient(ad_backend, P)

    results = DynamicHMC.mcmc_with_warmup(
        rng,
        ∇P,
        N;
        reporter = reporter
    )
    T = typeof(t(zeros(t.dimension)))

    # x = TupleArray{T,1}(undef, N)

    # for j in 1:N
    #     @inbounds x[j] = TransformVariables.transform(t, results.chain[j])
    # end

    # return x


    samples = TransformVariables.transform.(t, results.chain)
    return samples
end

using Random
rng = Random.GLOBAL_RNG


# One million data points, 5 parameters + intercept
N = 1000000;
k = 5;
X = randn(N,k);
α = 10.0;
β = randn(k);
σ = 0.2;
y = α .+ X * β + σ * randn(N);

using Soss

# Whatever prior you want
pr = @model k begin
    α ~ Cauchy()
    β ~ Normal() |> iid(k)
    σ ~ Exponential()
end;

# Sample from the posterior
@time post = bayeslm(rng, X, y, pr);
