using Pkg
Pkg.activate(".")
using Revise
using Soss
using NamedTupleTools
# using BenchmarkTools
# using Traceur
import TransformVariables
using Plots
using Lazy
using PositiveFactorizations
using LinearAlgebra
using PDMats

# register_primitive(logdensity)

# Kish's effective sample size,
# $n _ { \mathrm { eff } } = \frac { \left( \sum _ { i = 1 } ^ { n } w _ { i } \right) ^ { 2 } } { \sum _ { i = 1 } ^ { n } w _ { i } ^ { 2 } }$

function n_eff(ℓ)
    logw = ℓ.particles
    exp(2 * logsumexp(logw) - logsumexp(2 .* logw))
end

asmatrix(ps) = Matrix([ps...])'

using Dists: MvNormalStats
function Base.:+(ss1::MvNormalStats,ss2::MvNormalStats)
    tw = ss1.tw + ss2.tw
    s = ss1.s .+ ss2.s
    m = s .* inv(tw)
    s2 = cholesky(Positive, ss1.s2 + ss2.s2) |> Matrix
    MvNormalStats(s, m, s2, tw)
end


using Dists: MvNormalStats
function Base.:*(k::Real,ss::MvNormalStats)
    tw = k * ss.tw
    s = k * ss.s
    m = s .* inv(tw)
    s2 = cholesky(Positive, k * ss.s2) |> Matrix
    MvNormalStats(s, m, s2, tw)
end

Base.:*(ss::MvNormalStats, k::Real) = k * ss

function logwavg(a,wa,b,wb)
    w1 = logistic(wb-wa)
    w2 = 1-w1
    w1 > 0.9 && return a 
    w2 > 0.9 && return b 
    w1 * a + w2 * b
end



function makeplot(ℓ,θ,dat)
    @unpack α,β,σ = θ
    @unpack x,y=dat
    ℓmax = maximum(ℓ.particles)
    xs = range(extrema(x)...,length=100)
    plt = scatter(x,y, legend=false)
    # plot!(plt,xs, α .+ β .* xs, legend=false)
    @inbounds for j in eachindex(ℓ.particles)
        alph = exp(ℓ[j]-ℓmax)
        if alph > 0.5
            plot!(plt,xs, α[j] .+ β[j] .* xs, alpha=exp(ℓ[j]-ℓmax), legend=false)
        end
    end
    plt
end


# Expected value of x log-weighted by ℓ
function expect(x,ℓ)
    w = exp(ℓ - maximum(ℓ))
    mean.(x*w) / mean(w)
end

function self_outer(v)
    reshape(v, :, 1) * reshape(v, 1, :)
end 

@inline function visStep(N,logp,q)
    x = Particles(N,q)
    ℓ = logp(x) - logdensity(q,x)
    μ = expect(x,ℓ)
    Σ = cholesky(Positive, expect(0.5 * self_outer(x-μ),ℓ)) |> PDMat
    return (x,ℓ,μ,Σ)
end

function runInference(m; kwargs...)
    ℓp_pre = sourceLogdensity(m) |> eval
    ℓp(θ) = Base.invokelatest(ℓp_pre, θ) 
    t = xform(m; kwargs...)
    d = t.dimension
    tnames = propertynames(t.transformations)

    # make kwargs a NamedTuple
    kwargs = (;zip(keys(kwargs), values(kwargs))...)

    function logp(x::Vector{T} where T)
        prep(θ) = merge(kwargs, θ)
        f = transform_logdensity(t, ℓp ∘ prep, x)
    end

    logp(x) = logp([x])

    θ = particles(prior(m)) 

    x = @as xx θ begin
        mapslices(namedtuple(tnames),asmatrix(xx),dims=1)
        inverse(t).(xx)
        hcat(xx...)
        mapslices(Particles,xx,dims=2)
        vec(xx)
    end
    N = 1000
    q = fit_mle(MvNormal, asmatrix(x))
    x = Particles(N,q)
    ℓ = logp(x) - logdensity(q,x)


    plts = []
    neff = [n_eff(ℓ)]
    numiters = 100
    elbo = [max(mean(ℓ),expect(ℓ,ℓ))]
    for j in 1:numiters
        (x,ℓ,μ,Σ) = visStep(N,logp,q)
        @inbounds @show j, elbo[end], neff[end]
        push!(elbo, max(mean(ℓ),expect(ℓ,ℓ)))
        push!(neff, n_eff(ℓ))
        @inbounds neff[end] > 950 && break
        
        # η = (neff[end] )/(neff[end] +neff[end-1])
        η = 0.8 # learning rate
        μ = η * μ + (1-η) * q.μ
        Σ = η * Σ + (1-η) * q.Σ
        q = MvNormal(μ,1.5 * Σ)
    end

    x = Particles(N,q)
    θ = t(x)
    ℓ = logp(x) - logdensity(q,x)
    (θ,q,ℓ,elbo,neff)
end


m = @model x begin
        μ ~ Cauchy()
        σ ~ HalfCauchy()
        N = length(x)
        x ~ Normal(μ, σ) |> iid(N)
    end


thedata = (x=randn(1000),)

(θ,q,ℓ,elbo,neff) = runInference(m; thedata...)
plot(elbo, label="ELBO")
plot(neff, label="Effective Sample Size")

θ
# (α = thedata.α, β = thedata.β)#, σ = thedata.σ)

@unpack μ,σ = θ

scatter(μ.particles,σ.particles, alpha=exp(ℓ - maximum(ℓ)).particles)
