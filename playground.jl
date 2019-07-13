using Pkg
Pkg.activate(".")
using Revise
using Soss
using NamedTupleTools
# using BenchmarkTools
# using Traceur
using TransformVariables
using Plots
using Lazy
using PositiveFactorizations
using LinearAlgebra
using PDMats

for f in [<=, >=, <, >]
    register_primitive(f)
end
# register_primitive(logpdf)


asmatrix(ps) = Matrix([ps...])'

using Distributions: MvNormalStats
function Base.:+(ss1::MvNormalStats,ss2::MvNormalStats)
    tw = ss1.tw + ss2.tw
    s = ss1.s .+ ss2.s
    m = s .* inv(tw)
    s2 = cholesky(Positive, ss1.s2 + ss2.s2) |> Matrix
    MvNormalStats(s, m, s2, tw)
end


using Distributions: MvNormalStats
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

function prob_improvement(ℓ,ℓnew)
    oldsamp = ℓ.particles[rand(DiscreteUniform(1,1000),100)]
    newsamp = ℓnew.particles[rand(DiscreteUniform(1,1000),100)]
    mean(newsamp .> oldsamp)
    # @show maximum(ℓ) - minimum(ℓnew)
    # # Approximate P(ℓnew-ℓ)>0
    # old = ℓ 
    # new = ℓnew 
    # μ = mean(new) - mean(old)
    # σ = sqrt(var(old) + var(new))
    # ccdf(Normal(μ,σ),0.0)
end


function runInference(m; kwargs...)
    ℓp_pre = sourceLogdensity(m) |> eval
    ℓp(θ) = Base.invokelatest(ℓp_pre, θ) 
    t = getTransform(m)
    d = t.dimension
    tnames = propertynames(t.transformations)

    kwargs = collect(pairs(kwargs)) |> namedtuple

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
    ℓ = logp(x) - logpdf(q,x)
    # ss = suffstats(MvNormal, asmatrix(x),  exp.(ℓ.particles) )
    # ss.s2 .= cholesky(Positive, ss.s2) |> Matrix
    # @show ss.s2
    # μ = expect(x,ℓ)
    # Σ = expect(0.5 * self_outer(x-μ),ℓ)
    # q = MvNormal(μ,Σ)

    plts = []
    numiters = 20
    elbo = [expect(ℓ,ℓ)]
    for j in 1:numiters
        x = Particles(N,q)
        ℓnew = logp(x) - logpdf(q,x)
        # if expect(ℓnew, ℓnew) > expect(ℓ,ℓ)
            # @show ℓ,ℓnew
            ℓ = ℓnew
            @show ℓ
            push!(elbo, expect(ℓ,ℓ))
            μ = expect(x,ℓ)
            Σ = cholesky(Positive, expect(0.5 * self_outer(x-μ),ℓ)) |> PDMat
            
            η = 0.8 # learning rate
            μ = η * μ + (1-η) * q.μ
            Σ = η * Σ + (1-η) * q.Σ
            q = MvNormal(μ,1.5 * Σ)
            # ss += suffstats(MvNormal, asmatrix(x),  exp.(ℓ.particles) .+ eps(Float64))
            # ss.s2 .= cholesky(Positive, ss.s2) |> Matrix
            # q = fit_mle(MvNormal, ss)
        # end
        
        # mask = ℓ.particles .> quantile(ℓ,0.9)
        # @show Particles(ℓ.particles[mask])
        # newss = suffstats(MvNormal, asmatrix(x)[:,mask],  exp.(ℓ.particles[mask]) )#.+ eps(Float64))
        # newss = suffstats(MvNormal, asmatrix(x),  exp.(ℓ.particles) )#.+ eps(Float64))
        
        # ss += newss #logwavg(ss,elbo[end-1], newss,elbo[end])
        # q = fit_mle(MvNormal, ss)
        # ss *= 0.5
        # push!(plts,makeplot(ℓ,θ,kwargs))        
    end
    x = Particles(N,q)
    θ = t(x)
    ℓ = logp(x) - logpdf(q,x)
    (θ,q,ℓ,elbo)
end


m = linReg1D

thedata = let
    n = 100
    x = randn(n)
    y = 2 .* x .+ rand(TDist(5),n)
    (x=x,y=y)
end

@trace (θ,q,ℓ,elbo) = runInference(m; thedata...)
plt = plot(elbo, label="ELBO")


θ
# (α = thedata.α, β = thedata.β)#, σ = thedata.σ)

@unpack α,β,σ = θ

scatter(α.particles,β.particles, alpha=exp(ℓ - maximum(ℓ)).particles)

xs = range(extrema(thedata.x)..., length=100)
plt = scatter(thedata.x, thedata.y, legend=false)
@inbounds for j in eachindex(α.particles)
    plot!(plt, xs, α.particles[j] .+ β.particles[j] .* xs,alpha=exp(ℓ-maximum(ℓ)).particles[j])
end
plt