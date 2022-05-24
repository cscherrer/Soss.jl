using Soss
using SampleChains
using SampleChainsDynamicHMC
using Statistics
using LinearAlgebra
using Random
using Tullio

function loglik(X,y) 
    (N,k) = size(X)
    yᵗy = y' * y
    yᵗX = vec(y' * X)
    XᵗX = X' * X
    ∑X = vec(sum(X; dims=1))
    ∑y = sum(y)

    function f(α, β, σ)
        # If α==0 this would be
        # -N * log(σ) - 0.5/σ^2 * (yᵗy - 2 * yᵗX * β + β' * XᵗX * β)
        t0 = yᵗy - α * (2∑y - N * α)
        @tullio t1 = 2β[i] * (α * ∑X[i] - yᵗX[i])
        @tullio t2 = β[i] * XᵗX[i,j] * β[j]
        -N * log(σ) - 0.5/σ^2 * (t0 + t1 + t2)
    end 
    return f
end

function makeℓ(X, y, pr)
    k = size(X,2)
    ll = loglik(X,y)
    ℓ(pars) = ll(pars.α, pars.β, pars.σ) + logdensity_def(pr(k=k), pars)
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
    ℓ = makeℓ(X, y, pr)
    t = as(pr(k=size(X,2)))


    chain = initialize!(DynamicHMCChain, ℓ, t)

    drawsamples!(chain,N-1)
end


rng = Random.GLOBAL_RNG


# One million data points, 4 parameters + intercept
N = 1000000;
k = 4;
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
@time chain = bayeslm(rng, X, y, pr; N=1000)
