


####################

using Soss
using SampleChainsDynamicHMC


p = @model k,x begin
    σ ~ Exponential()
    α ~ Normal()
    β ~ Normal() |> iid(k)
    yhat = α .+ x * β
    y ~ For(eachindex(yhat)) do j
        Normal(μ = yhat[j], σ=σ)
    end
    return y
end;

m = @model k,x begin
    σ ~ Exponential()
    α ~ Normal()
    β ~ Normal() |> iid(k)
    yhat = α .+ x * β
    y ~ For(eachindex(yhat)) do j
        Normal(μ = yhat[j], σ=σ)
    end
    return y
end;

k=1

x = randn(1000,k)

y = rand(p(k=k,x=x))



post = m(k=k, x=x) | (;y)

ℓ(nt) = logdensity(post, nt) ;

t = xform(post);

chains = initialize!(DynamicHMCChain, ℓ, t);
drawsamples!(chains, 199)

drawsamples!(chains, 800)

pred = [predict(Soss.withmeasures(m)(k=k, x=x), c) for c in chains];
yhat = hcat(getproperty.(pred, :yhat)...)
d = getproperty.(pred, :_y_dist)
ppc = hcat((cdf.(dj.data, y) for dj in d)...)

using StatsBase
using AverageShiftedHistograms

function grassfire(v,m)
    ordv = ordinalrank(v)
    n = length(v)
    (lo,hi) = extrema(m)
    Δ = (hi-lo)/20
    lo = lo - Δ
    hi = hi + Δ
    a = ash(ordv, m[:,1]; rngx=range(1-n/20,n+n/20,length=800), rngy=range(lo,hi,length=600), kernelx=AverageShiftedHistograms.Kernels.uniform, kernely=AverageShiftedHistograms.Kernels.uniform)
    for j in 2:size(m,2)
        ash!(a,ordv, m[:,j])
    end
    ash!(a; mx=3,my=10)

    # [ash(ordv, m[:,j]; rngx=range(1-n/20,n+n/20,length=800), rngy=range(lo,hi,length=600)) for j in 1:size(m,2)]
end

# a = grassfire(y,ppc)

a = grassfire(vec(mean(yhat, dims=2)),ppc) 
using Plots
plot(a)






b = grassfire(vec(x),y .-yhat)
plot(b)

using Plots


scatter(ordinalrank(y), ppc)

using NestedTuples: rmap
rmap(length, chains)



# chain1 = initialize!(DynamicHMCChain, ℓ, t);
# drawsamples!(chain1,1000)

# chain2 = initialize!(DynamicHMCChain, ℓ, t);
# drawsamples!(chain2,1000)

# chain3 = initialize!(DynamicHMCChain, ℓ, t);
# drawsamples!(chain3,1000)

# chains = MultiChain(chain1, chain2, chain3)
