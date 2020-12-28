using StableRNGs
using Test

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
end

rng = StableRNG(42)
X = randn(rng, 20,2)
truth = rand(rng, m(X=X))
post = dynamicHMC(rng, m(X=X) |  (y=truth.y,))
pred = predictive(m,:β)

@testset "dynamicHMC" begin
    @test abs(sum(mean(v.β for v in post)) - -2.084) < 0.05
    @test_nowarn [rand(rng, pred(;X=X, p...)).y for p in post];
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
    @test logdensity(jointdist, truth) ≈ -28.551921801470908
    # @test logdensity(jointdist, truth, codegen) ≈ -28.551921801470904
end
