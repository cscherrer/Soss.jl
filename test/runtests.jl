using Soss
using Test
using Weave

function buildREADME() 
    weave("../README.jmd", doctype= "github", cache=:refresh, args=Dict(:seed => 6))
    return true
end

# write your own tests here
@testset "README" begin
    @test buildREADME()
end