using Soss
using Test
using Weave

function buildREADME() 
    weave("../README.jmd", doctype= "github", throw_errors=true, cache=:refresh, args=Dict(:seed => 6))
    return true
end

# write your own tests here
@testset "README" begin
    @test buildREADME()
end