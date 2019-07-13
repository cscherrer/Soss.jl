
using NamedTupleTools
using TransformVariables
using Lazy


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
    s2 = ss1.s2 + ss2.s2
    MvNormalStats(s, m, s2, tw)
end


using Distributions: MvNormalStats
function Base.:*(k::Real,ss::MvNormalStats)
    tw = k * ss.tw
    s = k * ss.s
    m = s .* inv(tw)
    s2 = k * ss.s2
    MvNormalStats(s, m, s2, tw)
end

function logwavg(a,wa,b,wb)
    w1 = logistic(wa-wb)
    w2 = 1-w1
    w1 > 0.9 && return a 
    w2 > 0.9 && return b 
    w1 * a + w2 * b
end

function Base.:*(ss::MvNormalStats, k::Real)
    tw = k * ss.tw
    s = k * ss.s
    m = s .* inv(tw)
    s2 = k * ss.s2
    MvNormalStats(s, m, s2, tw)
end

function makeplot(ℓ,x,y,θ,t)
    @unpack α,β,σ = t(θ)
    ℓmax = maximum(ℓ)
    j = argmax(ℓ)
    xs = range(extrema(x)...,length=100)
    plt = scatter(x,y, legend=false)
    # plot!(plt,xs, α .+ β .* xs, legend=false)
    for j in 1:20
        plot!(plt,xs, α[j] .+ β[j] .* xs, alpha=exp(ℓ[j]-ℓmax), legend=false)
    end
    plt
end

function varimpsampling(m; kwargs...)
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
    N = 100
    q = fit_mle(MvNormal, asmatrix(x))
    x = Particles(N,q)
    θ = t(x)
    # θm = asmatrix(θ)
    ℓ = logp(x) - logpdf(q,x)
    # @show ℓ
    ss = exp(mean(ℓ)) * suffstats(MvNormal, asmatrix(x),  exp(ℓ - mean(ℓ)).particles .+ one(Float64)/N)
    # q = fit_mle(MvNormal, ss)


    plts = []
    numiters = 200
    elbo = [mean(ℓ)]
    for j in 1:numiters
        x = Particles(N,q)
        θ = t(x)
        ℓ = logp(x) - logpdf(q,x)
        @show extrema(θ.σ)
        push!(elbo, mean(ℓ))

        newss = suffstats(MvNormal, asmatrix(x),  exp(ℓ-maximum(ℓ)).particles .+ one(Float64)/N)
        ss = logwavg(ss,elbo[end-1], newss,elbo[end])
        # exp(elbo[end] - elbo[end-1]) *
        q = fit_mle(MvNormal, ss)
        # q = MvNormal(q.μ .+ q0.μ, q.Σ + q0.Σ)
        # push!(plts,makeplot(ℓ,x,y,θ,t))
        ℓ
        
    end
    (θ,q,ℓ,elbo, ss)
end




