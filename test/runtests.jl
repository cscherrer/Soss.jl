using Soss
using Test

include("examples-list.jl")

@testset "Soss.jl" begin
    @testset "Unit tests" begin
        @testset "Linear model" begin
            include("linear-model.jl")
        end

        @testset "Transforms" begin
            include("transforms.jl")
        end
    end

    @testset "Examples" begin
        for example in EXAMPLES
            @testset "Run example: $(example[1])" begin
                example_file = joinpath(EXAMPLESROOT, "example-$(example[2]).jl")
                extra_example_tests = joinpath(TESTROOT, "extra-example-tests", "$(example[2]).jl")
                @info("Running $(example_file)")
                include(example_file)
                if isfile(extra_example_tests)
                    @info("Running $(extra_example_tests)")
                    include(extra_example_tests)
                end
            end
        end
    end

    @testset "Doctests" begin
        include("doctests.jl")
    end
end
