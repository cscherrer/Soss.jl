using StableRNGs

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
end

rng = StableRNG(42)
X = randn(rng, 6,2)
truth = rand(rng, m(X=X))
post = dynamicHMC(rng, m(X=X), (y=truth.y,))
pred = predictive(m,:β)

@testset "dynamicHMC" begin
    @test sum(v.β for v in post) == [137.9498847939604, 1253.8966977259338]
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

@testset "logpdf, symlogpdf" begin
    @test_nowarn symlogpdf(m2).evalf(3)
    @test logpdf(jointdist, truth)==-11.416468749176302
    @test logpdf(jointdist, truth, codegen)==-11.4164687491763
end
