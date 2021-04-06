using Soss
using Test
using MeasureTheory

include("examples-list.jl")

@testset "Soss.jl" begin
    @testset "Unit tests" begin
        @testset "Linear model" begin
            # include("linear-model.jl")
        end

        @testset "Transforms" begin
            include("transforms.jl")
        end
    end

    @testset "Examples" begin
        for example in EXAMPLES
            @testset "Run example: $(example[1])" begin
                # example_file = joinpath(EXAMPLESROOT, "example-$(example[2]).jl")
                # extra_example_tests = joinpath(TESTROOT, "extra-example-tests", "$(example[2]).jl")
                # @info("Running $(example_file)")
                # include(example_file)
                # if isfile(extra_example_tests)
                #     @info("Running $(extra_example_tests)")
                #     include(extra_example_tests)
                # end
            end
        end
    end

    @testset "Nested models" begin
        nested = @model a, b begin
            p ~ Beta(a, b)
            x ~ Normal(p, 1.0) |> iid(3)
        end

        m = @model sub begin
            a ~ Beta(0.5, 0.5)
            b ~ Beta(1, 0.5)
            m ~ sub(a = a, b = b)
        end

        outer = m(sub=nested)
        t = xform(outer | (; m = (; x = rand(3))))
        @test logdensity(outer | (; m = (; x = rand(3))), t(randn(3))) isa Float64
        
    end

    @testset "Doctests" begin
        include("doctests.jl")
    end
end
