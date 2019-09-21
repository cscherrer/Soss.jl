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

m = @model x begin
    α ~ Cauchy()
    β ~ Normal()
    σ ~ HalfNormal()
    y ~ For(x) do xj
        Normal(α + β * xj, σ)
    end
end;




using Plots
xx = range(extrema(truth.x)...,length=100)
plot(xx, truth.α .+ truth.β .* xx, legend=false)
scatter!(truth.x,truth.y)


post = dynamicHMC(m(x=truth.x), (y=truth.y,)); 
particles(post)

pred = predictive(m, :α, :β, :σ)