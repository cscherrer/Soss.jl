using Soss
using MeasureTheory
import TransformVariables as TV
using Aqua
Aqua.test_all(Soss; ambiguities=false, unbound_args=false)

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
        @test logdensity(post, transform(t, randn(3))) isa Float64
    end

    @testset "https://github.com/cscherrer/Soss.jl/issues/258" begin
        m1 = @model begin
            x1 ~ Soss.Normal(0.0, 1.0)
            x2 ~ Dists.LogNormal(0.0, 1.0)
            return x1^2/x2
        end

        m2 = @model m begin
            μ ~ m
            y ~ Soss.Normal(μ, 1.0)
        end

        mm = m2(m=m1())
        
        @test xform(mm|(y=1.0,)) isa TransformVariables.TransformTuple
        @test basemeasure(mm | (y=1.0,)) isa ProductMeasure
        @test testvalue(mm) isa NamedTuple
    end

    @testset "https://github.com/cscherrer/Soss.jl/issues/258#issuecomment-819035325" begin
        m1 = @model begin
            x1 ~ Soss.Normal(0.0, 1.0)
            x2 ~ Dists.MvNormal(fill(x1,2), ones(2))
            return x2
        end
        
        m2 = @model m begin
            μ ~ m
            y ~ For(μ) do x 
                Soss.Normal(x, 1.0)
            end
        end
        
        mm = m2(m=m1())

        @test xform(mm|(;y=1.0,)) isa TransformVariables.TransformTuple
        @test basemeasure(mm | (y=1.0,)) isa ProductMeasure
        @test testvalue(mm) isa NamedTuple
    end

    @testset "Local variables" begin
        # https://github.com/cscherrer/Soss.jl/issues/253

        m = @model begin
            a ~ For(3) do x Normal(μ=x) end
            x ~ Normal(μ=sum(a))
        end

        @test_broken let t = xform(m2() | (; m = (; x = rand(3))))
            logdensity(m2() | (; m = (; x = rand(3))), t(randn(3))) isa Float64
        end
        
        @test digraph(m).N == Dict(:a => Set([:x]), :x => Set())
    end

    @testset "Doctests" begin
        include("doctests.jl")
    end
end
