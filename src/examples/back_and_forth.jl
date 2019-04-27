using Pkg
Pkg.activate(".")
using Soss

myModel = @model begin
    N ~ Poisson(100)
    K ~ Poisson(2.5)
    p ~ Dirichlet(K, 1.0)
    μ ~ Normal(0,1.5) |> iid(K)
    σ ~ HalfNormal(1)
    θ = [(m,σ) for m in μ]
    x ~ MixtureModel(Normal, θ, p) |> iid(N)
end

using Parameters
using Plots
pyplot()


using Random
using StatsPlots

m = @model begin
    p ~ Uniform()
    μ ~ Normal(0, 1.5) |> iid(2)
    σ ~ HalfNormal(1)
    θ = [(m, σ) for m in μ]
    x ~ MixtureModel(Normal, θ, [p,1-p]) |> iid(100)
end

Random.seed!(20)
grt = rand(m)
mplot(grt)

function mplot(data) 
    @unpack μ,σ,p,x = data
    p = [p, 1-p]
    lo,hi = extrema(x)
    lo=min(lo,-4)
    hi=max(hi,4)
    xs = range(lo,hi,length=1000)
    dist = MixtureModel(Normal, tuple.(μ,σ), p)
    plt = plot(xs, p[1] .* pdf.(Normal(μ[1],σ), xs)
        , legend=false, fill = (0, 0.1, :red), linecolor=:red
        , axis=nothing)
    plot!(plt, xs, p[2] .* pdf.(Normal(μ[2],σ), xs)
        , fill = (0, 0.1, :blue), linecolor=:blue)
    plot!(plt,xs, pdf.(dist, xs), legend=false, linewidth=2, linecolor=:black)
    scatter!(plt, x, zeros(size(x))
        , marker=:vline, markercolor=:black, markersize=10)
    xlims!((-4,4))
end

r = makeRand(m)
anim = @animate for i=1:100
    mplot(r())
end
gif(anim, "m.gif", fps = 1)

#############################
# Inverse model (posterior distribution)

m_fwd = m(:p,:μ,:σ)
r = makeRand(m_fwd)
anim = @animate for i=1:100
    v = merge(grt, r(; grt...))
    mplot(v)
end
gif(anim, "m_fwd.gif", fps = 3)


m_inv = m(:x)
post = nuts(m_inv; grt...)
post = post.samples

anim = @animate for par in post[1:100]
    par = merge(grt, par)
    mplot(par)
end
gif(anim, "m_inv.gif", fps = 1)

####################################
# Posterior predictive checks

using StatsBase
xs  = range(-4,4,length=100)
ppc = repeat(grt.x, 1, 1000)
r = makeRand(m_fwd)

plt = plot(xs,ecdf(grt.x).(xs)
    ,linewidth=3,legend=false,size=(1200,800), axis=nothing)
# Each column is a posterior prediction
for j in 1:1000
    ppc = r(;post[j]...).x
    plot!(plt, xs, (rand(100) ./ 100 .+ ecdf(ppc).(xs)) ./ 1.01,linewidth=3, linecolor=:black, linealpha=0.01)
end
plot!(xs,ecdf(grt.x).(xs),linewidth=5,legend=false,linecolor=:white)
plot!(xs,ecdf(grt.x).(xs),linewidth=4,legend=false,linecolor=:orange)
plt
savefig("ppc.png")
