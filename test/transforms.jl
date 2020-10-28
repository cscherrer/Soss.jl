# Check for Model equality up to reorderings of a few fields
function ≊(m1::Model,m2::Model)
    function eq_tuples(nt1::NamedTuple,nt2::NamedTuple)
        return length(nt1)==length(nt2) && all(nt1[k]==nt2[k] for k in keys(nt1))
    end
    return Set(arguments(m1))==Set(arguments(m2)) && m1.retn==m2.retn && eq_tuples(m1.dists,m2.dists) && eq_tuples(m1.vals,m2.vals)
end


m = @model (n,α,β) begin
    p ~ Beta(α, β)
    x ~ Binomial(n, p)
    z ~ Binomial(n, α/(α+β))
end

@testset "prior" begin
    m1 = Soss.prior(m, :x)
    @test Soss.prior(m, :x) ≊ @model (α, β) begin
        p ~ Beta(α, β)
    end
end


@testset "likelihood" begin
    m1 = Soss.likelihood(m, :x)
    @test Soss.likelihood(m, :x) ≊ @model (p, n) begin
        x ~ Binomial(n, p)
    end
end

m1 = prune(m, :z)
@testset "prune" begin
    @test prune(m, :x, :z) ≊ @model (α, β) begin
        p ~ Beta(α, β)
    end
    @test prune(m1, :n) ≊ @model (α, β) begin
        p ~ Beta(α, β)
    end
    @test prune(m, :p) ≊ @model (α, n, β) begin
        z ~ Binomial(n, α / (α + β))
    end

    # When I define these variables, the tests pass.
    # Doing "@test prune(m1, :p) ≊ @model begin end" strangely causes an error in @model about reducing over an empty collection.
    emptymodel = @model begin end
    @test prune(m1, :p) ≊ emptymodel
end

@testset "predictive" begin
    @test predictive(m, :p) ≊ @model (n, p) begin
        x ~ Binomial(n, p)
    end
end

@testset "Do" begin
    @test Do(m, :p, :z) ≊ @model (n, p) begin
        x ~ Binomial(n, p)
    end
    empty = @model begin end
    @test Do(m, variables(m)...) ≊ empty
end
