using Pkg
Pkg.activate(".")
using Soss

myModel = @model begin
    N ~ Poisson(100)
    K ~ Poisson(2.5)
    p ~ Dirichlet(K, 1.0)
    μ ~ Normal(0,1.5) |> iid(K)
    σ ~ HalfNormal(1)
    x ~ MixtureModel(Normal, tuple.(μ,σ), p) |> iid(N)
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
    x ~ MixtureModel(Normal, tuple.(μ, σ), [p,1-p]) |> iid(100)
end


Random.seed!(18);

grt = rand(m) 


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
anim = @animate for i=1:10
    mplot(r())
end
gif(anim, "m.gif", fps = 1)





using Parameters
mplot(grt)


r = makeRand(m)
anim = @animate for i=1:100
    mplot(r())
end
gif(anim, "m.gif", fps = 1)


m_fwd = m(:p,:μ,:σ)
r = makeRand(m_fwd)
anim = @animate for i=1:100
    v = merge(grt, r(; grt...))
    mplot(v)
end
gif(anim, "m_fwd.gif", fps = 3)

m_inv = m(:x)
post = nuts(m_inv; grt...).samples

anim = @animate for par in post[1:100]
    par = merge(grt, par)
    mplot(par)
end
gif(anim, "m_inv.gif", fps = 1)

d = MixtureModel(Normal, tuple.(μ,σ), p)
lo,hi = extrema(rand(d,1000))

xs = range(lo,hi,length=300)
plot(xs, pdf.(d,xs), legend=false)

using Plots
plt = plot(grt.x, grt.yhat, ribbon=(ε95 , ε95))
scatter!(plt, grt.x,grt.y, legend=false)

# plot!(plt, grt.x, grt.yhat)

m_fwd = m(:p, :μ, :σ)
m_inv = m(:x)

getMAP(m_inv, data=grt)


μpost = hcat(getfield.(s,:μ)...) |> transpose