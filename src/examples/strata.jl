using Revise
using Soss 


mt = @model x begin
    α ~ Cauchy()
    β ~ Normal()
    σ ~ HalfNormal()
    y ~ For(x) do xj
        Mix([Normal(α + β * xj, σ), StudentT(5, α + β * xj, 5*σ)], [0.9,0.1])
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


using Plots
xx = range(extrema(truth.x)...,length=100)
scatter(truth.x,truth.y, legend=false, c=1)
plot!(xx, truth.α .+ truth.β .* xx, dpi=300,legend=false, lw=3, c=2)
savefig("rawdata.png")

m = @model x begin
    α ~ Cauchy()
    β ~ Normal()
    σ ~ HalfNormal()
    yhat = α .+ β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], σ)
    end
end;



post = dynamicHMC(m(x=truth.x), (y=truth.y,)) #|> particles

eachplot(xx, post.α .+ post.β .* xx, lw=3, dpi=300)
scatter!(truth.x,truth.y, legend=false, c=1)
plot!(xx, truth.α .+ truth.β .* xx, legend=false, lw=3, c=2)
ylims!(-3,5)
savefig("fit1.png")

pred = predictive(m, :α, :β, :σ)

postpred= [rand(pred(θ)((x=x,))) for θ ∈ post] |> particles
p = sortperm(x)
eachplot(x[p], (truth.y - postpred.y)[p])


eachplot(x, ppc.yhat, lw=3)
scatter!(truth.x,truth.y, legend=false)
plot!(xx, truth.α .+ truth.β .* xx, legend=false, lw=3, c=2)
ylims!(-3,5)

eachplot(xx, )