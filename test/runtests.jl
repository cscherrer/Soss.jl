using Soss
using Test
using Weave
using Documenter

DocMeta.setdocmeta!(Soss, :DocTestSetup, 
    quote
        using Soss
        using Random
        Random.seed!(3)
    end; recursive=true)

function buildREADME()
    weave("../README.jmd", doctype= "github", throw_errors=true, cache=:refresh, args=Dict(:seed => 6))
    return true
end

# write your own tests here
@testset "README" begin
    @test buildREADME()
end

@testset "Doctests" begin
    doctest(Soss)
end
