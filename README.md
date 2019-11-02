# Soss

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://cscherrer.github.io/Soss.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://cscherrer.github.io/Soss.jl/dev)
[![Build Status](https://travis-ci.com/cscherrer/Soss.jl.svg?branch=master)](https://travis-ci.com/cscherrer/Soss.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/cscherrer/Soss.jl?svg=true)](https://ci.appveyor.com/project/cscherrer/Soss-jl)
[![Codecov](https://codecov.io/gh/cscherrer/Soss.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/cscherrer/Soss.jl)
[![Coveralls](https://coveralls.io/repos/github/cscherrer/Soss.jl/badge.svg?branch=master)](https://coveralls.io/github/cscherrer/Soss.jl?branch=master)

Soss is a library for _probabilistic programming_

Let's jump right in with a simple linear model:

```julia
using Soss 

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
end;
```

In Soss, models are _first-class_ and _function-like_, and "applying" a model to its arguments gives a _joint distribution_.

Just a few of the things we can do in Soss:

- Sample from the (forward) model
- Condition a joint distribution on a subset of parameters
- Have arbitrary Julia values (yes, even other models) as inputs or outputs of a model
- Build a new model for the _predictive_ distribution, for assigning parameters to particular values

Let's use our model to build some fake data:
```julia
julia> X = randn(6,2)
6×2 Array{Float64,2}:
  0.214743  -1.04389 
 -0.809179  -0.580583
  0.205876  -0.840331
 -0.568996   1.02659 
  1.19427    0.671222
  0.392438  -0.232703

julia> truth = rand(m(X=X));

julia> truth.β
2-element Array{Float64,1}:
 0.14338740065601344
 0.4233111052117538 
 
julia> truth.y
6-element Array{Float64,1}:
 -1.0438927843946528
 -0.5805833500446688
 -0.8403308441501461
  1.0265870371601737
  0.6712215914389901
 -0.2327030992653677
```

And now pretend we don't know `β`, and have the model figure it out. 
Often these are easier to work with in terms of `particles` (built using [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl)):

```julia
julia> post = dynamicHMC(m(X=truth.X), (y=truth.y,));

julia> particles(post)
(β = Particles{Float64,1000}[-0.0101 ± 0.55, 0.784 ± 0.47],)
```

For model diagnostics and prediction, we need the _predictive distribution_:
```julia
julia> pred = predictive(m,:β)
@model (X, β) begin
        y ~ For(eachrow(X)) do x
                Normal(x' * β, 1)
            end
    end
```

This requires `X` and `β` as inputs, so we can do something like this to do a _posterior predictive check_

```julia
ppc = [rand(pred(;X=truth.X, p...)).y for p in post];

julia> particles(ppc)
6-element Array{Particles{Float64,1000},1}:
 -0.425 ± 0.63 
 -0.697 ± 0.11 
 -0.312 ± 0.52 
  0.243 ± 0.8  
  0.949 ± 0.26 
  0.0774 ± 0.31

julia> truth.y - particles(ppc)
6-element Array{Particles{Float64,1000},1}:
 -1.01 ± 1.0 
 -0.326 ± 1.2
  0.817 ± 1.2
 -0.37 ± 1.2 
 -0.484 ± 1.3
 -0.317 ± 1.1
```

These play a role similar to that of residuals in a non-Bayesian approach (there's plenty more detail to go into, but that's fgor another time).



## What's Really Happening Here?

Under the hood, `rand` and `logpdf` specify different ways of "running" the model.

 `rand`  turns each `v ~ dist` into `v = rand(dist)`, finally outputting the `NamedTuple` of all values it has seen.

`logpdf` steps through the same program, but instead accumulates a log-density. It begins by initializing `_ℓ = 0.0`. Then at each step, it turns `v ~ dist` into `_ℓ += logpdf(dist, v)`, before finally returning `_ℓ`.

Note that I said "turns into" instead of "interprets". Soss uses [`GG.jl`](https://github.com/thautwarm/GG.jl) to generate specialized code for a given model, inference primitive (like `rand` and `logpdf`), and type of data. 

This idea can be used in much more complex ways. `weightedSample` is a sort of hybrid between `rand` and `logpdf`. For data that are provided, it increments a `_ℓ` using `logpdf`. Unknown values are sampled using `rand`.

```julia
julia> weightedSample(m(σ=1), (μ=0.0,))
(-0.9189385332046728, (σ = 1, μ = 0.0, x = [1.4022646662147151, 0.5619286714811451, 1.0666556455847045]))

julia> weightedSample(m(σ=1), (x=[-1,0,1],))
(-3.7839836623738043, (σ = 1, μ = 0.13458098617508069, x = [-1, 0, 1]))
```

Again, there's no runtime check needed for this. Each of these is compiled the first time it is called, so future calls are very fast. Functions like this are great to use in tight loops.



## To Do

We need a way to "lift" a "`Distribution`" (without parameters, so really a family) to a `Model`, or one with parameters to a `JointDistribution`

Models are "function-like", so a `JointDistribution` should be sometimes usable as a value. `m1(m2(args))` should work.

This also means `m1 ∘ m2` should be fine

Since inference primitives are specialized for the type of data, we can include methods for `Union{Missing, T}` data. PyMC3 has something like this, but for us it will be better since we know at compile time whether any data are missing.

There's a `return` available in case you want a result other than a `NamedTuple`, but it's a little fiddly still. I think whether the `return` is respected or ignored should depend on the inference primitive. And some will also modify it, similar to how a state monad works. Likelihood weighting is an example of this.

Rather than having lots of functions for inference, anything that's not a primitive should (I think for now at least) be a method of... let's call it `sample`. This should always return an iterator, so we can combine results after the fact using tools like `IterTools`, `ResumableFunctions`, and `Transducers`.

This situation just described is for generating a sequence of samples from a single distribution. But we may also have models with a sequence of distributions, either observed or sampled, or a mix. This can be something like Haskell's `iterateM`, though we need to think carefully about the specifics.

We already have a way to `merge` models, we should look into intersection as well.

We need ways to interact with Turing and Gen. Some ideas:

- Turn a Soss model into an "outside" (Turing or Gen) model
- Embed outside models as a black box in a Soss model, using their methods for inference

## Stargazers over time

[![Stargazers over time](https://starchart.cc/cscherrer/Soss.jl.svg)](https://starchart.cc/cscherrer/Soss.jl)


