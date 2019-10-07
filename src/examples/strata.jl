using Revise
using Soss 


mt = @model x begin
    α = 1.0
    β = 3.0
    σ = 0.5
    yhat = α .+ β .* x
    y ~ For(eachindex(x)) do j
        Mix([Normal(yhat[j], σ), Normal(yhat[j],10σ)], [0.8,0.2])
    end
end;

x = randn(100); 
truth = rand(mt(x=x));


using JLD
# save("strata-truth.jld", 
#     "α", truth.α, 
#     "β", truth.β, 
#     "σ", truth.σ,
#     "x", truth.x,
#     "y", truth.y)

truth = let
    d  = load("strata-truth.jld")
    (α = d["α"], β = d["β"], σ = d["σ"], x = d["x"], y = d["y"])
end

x = truth.x

using Plots
xx = range(extrema(truth.x)...,length=100)
scatter(truth.x,truth.y, legend=false, c=1)
plot!(xx, truth.α .+ truth.β .* xx, dpi=300,legend=false, lw=3, c=2)
savefig("rawdata.png")

m = @model x begin
    α ~ Cauchy()
    β ~ Normal()
    σ ~ HalfNormal(10)
    yhat = α .+ β .* x
    y ~ For(eachindex(x)) do j
            Normal(yhat[j], σ)
        end
end;



post = dynamicHMC(m(x=truth.x), (y=truth.y,)) 

ppost = particles(post)

eachplot(xx, ppost.α .+ ppost.β .* xx, lw=3, dpi=300)
scatter!(truth.x,truth.y, legend=false, c=1)
plot!(xx, truth.α .+ truth.β .* xx, legend=false, lw=3, c=2)
savefig("fit1.png")

pred = predictive(m, :α, :β, :σ)

postpred = [rand(pred(θ)((x=x,))) for θ ∈ post] |> particles

pvals = mean.(truth.y .> postpred.y)

# PPC vs x
scatter(truth.x, pvals, legend=false, dpi=300)
xlabel!("x")
ylabel!("Bayesian p-value")
savefig("ppc-x.png")


# PPC vs y
scatter(truth.y, pvals, legend=false, dpi=300)
xlabel!("y")
ylabel!("Bayesian p-value")
savefig("ppc-y.png")

using AverageShiftedHistograms

o = ash(pvals, rng=0:0.01:1, kernel=Kernels.cosine,m=8)
plot(o, legend=false,dpi=300)
xlabel!("Bayesian p-values")
savefig("ppc.png")


##########################################

m2 = @model x begin
    α ~ Cauchy()
    β ~ Normal()
    σ ~ HalfNormal(10)
    νinv ~ HalfNormal()
    yhat = α .+ β .* x
    y ~ For(eachindex(x)) do j
            StudentT(1/νinv,yhat[j],σ)
        end
end;

post2 = dynamicHMC(m2(x=truth.x), (y=truth.y,))
ppost2 = particles(post2)



eachplot(xx, ppost2.α .+ ppost2.β .* xx, lw=3, dpi=300)
scatter!(truth.x,truth.y, legend=false, c=1)
plot!(xx, truth.α .+ truth.β .* xx, legend=false, lw=3, c=2)
savefig("fit2.png")

pred2 = predictive(m2, setdiff(stochastic(m2), [:y])...)

post2pred= [rand(pred2(θ)((x=x,))) for θ ∈ post2]  |> particles

pvals2 = mean.(truth.y .> post2pred.y)

# PPC vs x
scatter(truth.x, pvals2, legend=false, dpi=300)
xlabel!("x")
ylabel!("Bayesian p-value")
savefig("ppc2-x.png")


# PPC vs y
scatter(truth.y, pvals2, legend=false, dpi=300)
xlabel!("y")
ylabel!("Bayesian p-value")
savefig("ppc2-y.png")

o = ash(pvals2, rng=0:0.01:1, kernel=Kernels.cosine,m=8)
plot(o, legend=false,dpi=300)
xlabel!("Bayesian p-values")
savefig("ppc2.png")



using Soss

m = @model begin
    μ ~ Normal() |> iid(2)
    σ ~ HalfNormal() |> iid(3)
    x ~ For(1:2,1:3) do i,j
        Normal(μ[i], σ[j])
    end
end;

truth = rand(m())

post = dynamicHMC(m(), (x=truth.x,)) |> particles

pred = predictive(m,:μ,:σ) 

predpost = pred(post) 

rand(predpost)