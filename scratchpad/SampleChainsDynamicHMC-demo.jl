using SampleChainsDynamicHMC
using Soss

g = @model N begin
    n ~ Poisson(10) |> iid(N)
    p ~ Uniform()
    y ~ For(n) do nj Binomial(nj, p) end
end;

obs = predict(g, N=5, p=0.2)

pairs(obs)

m = predictive(g, :n)

post = m(n=[6,12,7,8,12]) | (y=[1,3,1,2,3],)


s = sample(DynamicHMCChain, post)


predict(m(n=obs.n), s)



drawsamples!(s, 1000)

a1 = ash(getchains(s)[1].p)
a2 = ash(getchains(s)[2].p)
a3 = ash(getchains(s)[3].p)
a4 = ash(getchains(s)[4].p)


plot(a1.rng, a1.density)
plot!(a2.rng, a2.density)
plot!(a3.rng, a3.density)
plot!(a4.rng, a4.density)

drawsamples!(s, 10000)

p = 0.001:0.001:0.999
plot(p, exp.([ℓ((p=pj,)) for pj in p]))


using TransformVariables

ℓ(x) = logdensity_def(Beta(4,3), x.p)
t = as(post)
chain = initialize!(DynamicHMCChain, ℓ, t)
drawsamples!(chain, 10000)
plot(ash(chain.p))
