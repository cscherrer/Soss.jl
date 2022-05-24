using Soss
using Test
using MeasureTheory
import TransformVariables as TV
using TransformVariables: transform
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
        post = outer(sub=inner) | (m = (x=x,),)
        t = as(post)
        @test logdensityof(post, transform(t, randn(3))) isa Real
    end

    @testset "Predict" begin
        m = @model begin
            p ~ Uniform()
            y ~ Bernoulli(p)
            return y
        end
            
        mean(predict(m(), [(p=p,) for p in rand(10000)])) isa Float64
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
        
        @test as(mm|(y=1.0,)) isa TV.TransformTuple
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

        @test as(mm|(;y=1.0,)) isa TV.TransformTuple
        @test basemeasure(mm | (y=1.0,)) isa ProductMeasure
        @test testvalue(mm) isa NamedTuple
    end

    @testset "https://github.com/cscherrer/Soss.jl/issues/305" begin
        m = @model begin 
            x ~ For(3) do j Normal(μ=j) end
        end;
        
        @test logdensityof(m(), rand(m())) isa Float64
    end

    @testset "Local variables" begin
        # https://github.com/cscherrer/Soss.jl/issues/253

        m = @model begin
            a ~ For(3) do x Normal(μ=x) end
            x ~ Normal(μ=sum(a))
        end

        @test digraph(m).N == Dict(:a => Set([:x]), :x => Set())
    end

    @testset "Doctests" begin
        include("doctests.jl")
    end

    @testset "Distributions" begin
        m = @model begin
            a ~ Normal() |> iid(3)
            b ~ Dists.Normal() |> iid(3)
            c ~ For(3) do i
                Normal(μ = a[i] +b[i])
            end
        end

        c = rand(m()).c

        post = m() | (c=c,)

        @test transform(as(post), randn(6)) isa NamedTuple

        @testset "logdensity" begin
            dat = randn(100)
            m = Soss.@model n begin
                μ ~ Dists.Normal()
                σ ~ Dists.Exponential()
                data ~ Dists.Normal(μ, σ) |> iid(n)
                return (; data)
            end
            mod = m( (; n = length(dat) ) )
            post = mod | (data = dat,)

            @test logdensityof( mod( (μ = 1., σ = 2., data = dat) ) ) == logdensityof( post( (μ = 1., σ = 2.) ) )
        end


    end

    @testset "basemeasure" begin
        m = @model n begin
            p ~ Uniform()
            x ~ Bernoulli(p) ^ n
        end

        post = m(10) | (x = rand(Bool, 10),)
        base = basemeasure(post)
        @test logdensity_def(base, (p=0.2, x=post.obs.x)) isa Real
    end
end
