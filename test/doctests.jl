using Documenter

DocMeta.setdocmeta!(Soss, :DocTestSetup,
    quote
        using Soss
        using Random
        using StableRNGs
        Random.seed!(3)
    end; recursive=true)

@testset "Doctests" begin
    doctest(Soss)
end
