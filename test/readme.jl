using Weave
using Documenter

function buildREADME()
    set_chunk_defaults!(:error=>false)
    weave("../README.jmd", doctype= "github", cache=:refresh, args=Dict(:seed => 6))
    return true
end

# write your own tests here
@testset "README" begin
    @test buildREADME()
end
