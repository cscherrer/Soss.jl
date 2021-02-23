using Soss
using SampleChains
using SampleChainsDynamicHMC
using Statistics
using LinearAlgebra
using Random

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
    pr;
    N::Int = 1000,
    ad_backend = Val(:ForwardDiff),
    kwargs...,
)
    ℓ = makelogp(X, y, pr)
    t = xform(pr(k=size(X,2)))


    chain = initialize!(DynamicHMCChain, ℓ, t)

    drawsamples!(chain,N)
end


rng = Random.GLOBAL_RNG


# One million data points, 5 parameters + intercept
N = 1000;
k = 20;
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
@time chain = bayeslm(rng, X, y, pr; N=100)
