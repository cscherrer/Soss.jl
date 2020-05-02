using Soss
using Test
using Weave
using Documenter

DocMeta.setdocmeta!(Soss, :DocTestSetup, :(using Soss); recursive=true)

function buildREADME()
    weave("../README.jmd", doctype= "github", throw_errors=true, cache=:refresh, args=Dict(:seed => 6))
    return true
end

# write your own tests here
#@testset "README" begin
#    @test buildREADME()
#end

@testset "Doctests" begin
    doctest(Soss)
end
