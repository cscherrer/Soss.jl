
# Soss

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://cscherrer.github.io/Soss.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://cscherrer.github.io/Soss.jl/dev)
[![Build Status](https://github.com/cscherrer/Soss.jl/workflows/CI/badge.svg)](https://github.com/cscherrer/Soss.jl/actions)
[![Coverage](https://codecov.io/gh/cscherrer/Soss.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/cscherrer/Soss.jl)

Soss is a library for _probabilistic programming_.

Let's look at an example. First we'll load things:

```julia
using MeasureTheory
using Soss
```

[MeasureTheory.jl](https://github.com/cscherrer/MeasureTheory.jl) is designed specifically with PPLs like Soss in mind, though you can also use Distributions.jl.


Now for a model. Here's a linear regression:

```julia
m = @model x begin
    α ~ Lebesgue(ℝ)
    β ~ Normal()
    σ ~ Exponential()
    y ~ For(x) do xj
        Normal(α + β * xj, σ)
    end
    return y
end
```

Next we'll generate some fake data to work with. For `x`-values, let's use

```julia
x = randn(20)
```

Now loosely speaking, `Lebesgue(ℝ)` is uniform over the real numbers, so we can't really sample from it. Instead, let's transform the model and make `α` an argument:

```julia
julia> predα = predictive(m, :α)
@model (x, α) begin
        σ ~ Exponential()
        β ~ Normal()
        y ~ For(x) do xj
                Normal(α + β * xj, σ)
            end
        return y
    end
```

Now we can do
```julia
julia> y = rand(predα(x=x,α=10.0))
20-element Vector{Float64}:
 10.554133456468438
  9.378065258831002
 12.873667041657287
  8.940799408080496
 10.737189595204965
  9.500536439014208
 11.327606120726893
 10.899892855024445
 10.18488773139243
 10.386969795947177
 10.382195272387214
  8.358407507910297
 10.727173015711768
 10.452311211064654
 11.076232496702387
 11.362009520020141
  9.539433052406448
 10.61851691333643
 11.586170856832645
  9.197496058151618
```

Now for inference! Let's use `DynamicHMC`, which we have wrapped in `SampleChainsDynamicHMC`.

```julia
julia> using SampleChainsDynamicHMC
[ Info: Precompiling SampleChainsDynamicHMC [6d9fd711-e8b2-4778-9c70-c1dfb499d4c4]

julia> post = sample(DynamicHMCChain, m(x=x) | (y=y,))
4000-element MultiChain with 4 chains and schema (σ = Float64, β = Float64, α = Float64)
(σ = 1.0±0.15, β = 0.503±0.26, α = 10.2±0.25)
```

## How is Soss different from [Turing](https://turing.ml/dev/)?

First, a fine point: When people say "the Turing PPL" they usually mean what's technically called "DynamicPPL". 

- In Soss, models are first class, and can be composed or nested. For example, you can define a model and later nest it inside another model, and inference will handle both together. DynamicPPL can also handle nested models (see [this PR](https://github.com/TuringLang/DynamicPPL.jl/pull/233)) though I'm not aware of a way to combine independently-defined DynamicPPL models for a single inference pass.
- Soss has been updated to use [MeasureTheory.jl](https://github.com/cscherrer/MeasureTheory.jl), though everything from Distributions.jl is still available.
- Soss allows model transformations. This can be used, for example, to easily express predictive distributions or Markov blanket as a new model.
- Most of the focus of Soss is at the syntactic level; inference works in terms of "primitives" that transform the model's abstract syntax tree (AST) to new code. This adds the same benefits as using Julia's macros and generated functions, as opposed to higher-order functions alone.
- Soss can evaluate log-densities symbolically, which can then be used to produce optimized evaluations for much faster inference. This capability is in relatively early stages, and will be made more robust in our ongoing development.
- The Soss team is *much* smaller than that of DynamicPPL. But I hope that will change (contributors welcome!)

Soss and DynamicPPL are both maturing and becoming more complete, so the above will change over time. It's also worth noting that we (the Turing team and I) hope to move toward a natural way of using these systems together to arrive at the best of both.

## How can I get involved?

I'm glad you asked! Lots of things:

- Contribute documentation or tests
- Ask questions on Discourse or Zulip
- File issues for bugs (or other problems) or feature requests
- Use Soss in your applications, teaching, or blogging
- Get involved in other libraries in the Soss ecosystem:
    - [SossMLJ](https://github.com/cscherrer/SossMLJ.jl)
    - [SossGen](https://github.com/cscherrer/SossGen.jl) (needs updating)
    - [SampleChains](https://github.com/cscherrer/SampleChains.jl)
    - [SampleChainsDynamicHMC](https://github.com/cscherrer/SampleChainsDynamicHMC.jl)
    - [TupleVectors](https://github.com/cscherrer/TupleVectors.jl)
    - [NestedTuples](https://github.com/cscherrer/NestedTuples.jl)
    - [MeasureTheory](https://github.com/cscherrer/MeasureTheory.jl)
    - [SymbolicCodegen](https://github.com/cscherrer/SymbolicCodegen.jl)


For more details, please see the [documentation](https://cscherrer.github.io/Soss.jl/stable/).

## Stargazers over time

[![Stargazers over time](https://starchart.cc/cscherrer/Soss.jl.svg)](https://starchart.cc/cscherrer/Soss.jl)
