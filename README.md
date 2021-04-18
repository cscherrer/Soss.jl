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

For more details, please see the [documentation](https://cscherrer.github.io/Soss.jl/stable/).

## Stargazers over time

[![Stargazers over time](https://starchart.cc/cscherrer/Soss.jl.svg)](https://starchart.cc/cscherrer/Soss.jl)
