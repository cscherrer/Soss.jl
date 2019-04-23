myModel = @model begin
    N ~ Poisson(100)
    K ~ Poisson(2.5)
    p ~ Dirichlet(K, 1.0)
    μ ~ Normal(0,1.5) |> iid(K)
    σ ~ HalfNormal(1)
    x ~ MixtureModel(Normal, tuple.(μ,σ), p) |> iid(N)
end

m = myModel(N=100,K=2)



anim = @animate for i=1:100
    @unpack μ,σ,p,x = rand(m)
    lo,hi = extrema(x)
    lo=min(lo,-4)
    hi=max(hi,4)
    xs = range(lo,hi,length=1000)
    dist = MixtureModel(Normal, tuple.(μ,σ), p)
    plt=plot(xs, pdf.(dist, xs), legend=false)
    scatter!(plt, x, zeros(size(x)), marker=:vline)
end
gif(anim, "m.gif", fps = 1)




m = myModel(N=100, K=2)
m_fwd = m(:p,:μ,:σ)
m_inv = m(:x)
using Random
Random.seed!(1);



using StatsPlots

grt = rand(m) 
using Parameters
@unpack μ,σ,p = grt

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
