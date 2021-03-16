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
                extra_example_tests =
                    joinpath(TESTROOT, "extra-example-tests", "$(example[2]).jl")
                @info("Running $(example_file)")
                include(example_file)
                if isfile(extra_example_tests)
                    @info("Running $(extra_example_tests)")
                    include(extra_example_tests)
                end
            end
        end
    end

    @testset "`For` methods" begin
        @info "Testing `For` methods"
        for indices in [3, 1:3, (j for j = 1:3), [1, 2, 3], rand(2, 3)]
            d = For(i -> Normal(0.0, i), indices)

            x = logdensity(d, rand(d))
            y = logdensity(d, rand.(collect(d)))
        end

        for indices in [(2, 3), (1:2, 1:3)]
            d = For((i, j) -> Normal(i, j), indices)

            x = logdensity(d, rand(d))
            y = logdensity(d, rand.(collect(d)))
        end
    end

    @testset "Nested models" begin
        m1 = @model a, b begin
            p ~ Beta(a, b)
            x ~ Normal(p, 1.0) |> iid(3)
        end


        m2 = @model begin
            a ~ Beta(0.5, 0.5)
            b ~ Beta(1, 0.5)
            m ~ m1(a = a, b = b)
        end

        t = xform(m2() | (; m = (; x = rand(3))))

        @test logdensity(m2() | (; m = (; x = rand(3))), t(randn(3)))
    end

    @testset "Doctests" begin
        include("doctests.jl")
    end
end
