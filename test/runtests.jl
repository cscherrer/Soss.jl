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
        inner = @model a, b begin
            p ~ Beta(a, b)
            x ~ Normal(p, 1.0) |> iid(3)
            return x
        end

        outer = @model sub begin
            a ~ Beta(0.5, 0.5)
            b ~ Beta(1, 0.5)
            m ~ sub(a = a, b = b)
        end

        x = rand(outer(sub=inner)).m
        post = outer(sub=inner) | (;m=  (; x))
        t = xform(post)
        @test logdensity(post, t(randn(3))) isa Float64
    end

    @testset "Doctests" begin
        include("doctests.jl")
    end
end
