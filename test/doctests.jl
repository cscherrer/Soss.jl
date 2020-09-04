using Documenter
using Random
using Soss
using StableRNGs

DocMeta.setdocmeta!(Soss, :DocTestSetup,
    quote
        using Random
        using Soss
        using StableRNGs
        Random.seed!(3)
    end; recursive=true)

@testset "Doctests" begin
    doctest(Soss)
end
