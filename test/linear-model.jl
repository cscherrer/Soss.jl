using StableRNGs
using Test
using Statistics
using BayesianLinearRegression

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
    return collect(y)
end

rng = StableRNG(42)
X = randn(rng, 20, 2)
truth = simulate(rng, m(X=X))
y = value(truth)
post = dynamicHMC(rng, m(X=X) |  (y=y,))
pred = predictive(m,:β)

lr = BayesianLinReg(X,y)
lr.updateNoise = false
lr.updatePrior = false
fit!(lr)


@testset "dynamicHMC" begin
    @test mean(v.β for v in post) ≈ lr.weights  rtol = 0.05
    @test_nowarn [rand(rng, pred(;X=X, p...)) for p in post];
    #particles(post)
end

m2 = @model X begin
    N = size(X,1)
    k = size(X,2)
    β ~ Normal() |> iid(k)
    yhat = X * β
    y ~ For(N) do j
            Normal(yhat[j], 1)
        end
end;

jointdist = m2(X=X)

@testset "logdensity, symlogdensity" begin
    # @test_nowarn symlogdensity(m2).evalf(3)
    @test logdensity_def(jointdist, (β = truth.trace.β, y=y)) ≈ -8.015157812948065
    # @test logdensity_def(jointdist, truth, codegen) ≈ -28.551921801470904
end
