# Soss

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://cscherrer.github.io/Soss.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://cscherrer.github.io/Soss.jl/dev)
[![Build Status](https://travis-ci.com/cscherrer/Soss.jl.svg?branch=master)](https://travis-ci.com/cscherrer/Soss.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/cscherrer/Soss.jl?svg=true)](https://ci.appveyor.com/project/cscherrer/Soss-jl)
[![Codecov](https://codecov.io/gh/cscherrer/Soss.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/cscherrer/Soss.jl)
[![Coveralls](https://coveralls.io/repos/github/cscherrer/Soss.jl/badge.svg?branch=master)](https://coveralls.io/github/cscherrer/Soss.jl?branch=master)

Soss is a library for _probabilistic programming_.

## Getting started

Soss is an officially registered package, so to add it to your project you can type
````julia

]add Soss
````



within the julia REPL and your are ready for `using Soss`. If it fails to precompile, it could be due to one of the following:

* You have gotten an old version due to compatibility restrictions with your current environment.
Should that happen, create a new folder for your Soss project, launch a julia session within, type
````julia

]activate .
````



and start again. More information on julia projects [here](https://julialang.github.io/Pkg.jl/stable/environments/#Creating-your-own-projects-1).
* You have set up PyCall to use a python distribution provided by yourself. If that is the case, make sure to install the missing python dependencies, as listed in the precompilation error. More information on PyCall's python version [here](https://github.com/JuliaPy/PyCall.jl#specifying-the-python-version).

Let's jump right in with a simple linear model:

````julia
using Soss

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
end;
````





In Soss, models are _first-class_ and _function-like_, and "applying" a model to its arguments gives a _joint distribution_.

Just a few of the things we can do in Soss:

- Sample from the (forward) model
- Condition a joint distribution on a subset of parameters
- Have arbitrary Julia values (yes, even other models) as inputs or outputs of a model
- Build a new model for the _predictive_ distribution, for assigning parameters to particular values

Let's use our model to build some fake data:
````julia
julia> import Random; Random.seed!(3)

julia> X = randn(6,2)
6×2 Array{Float64,2}:
  1.19156    0.100793
 -2.51973   -0.00197414
  2.07481    1.00879
 -0.97325    0.844223
 -0.101607   1.15807
 -1.54251   -0.475159

````



````julia
julia> truth = rand(m(X=X));

julia> pairs(truth)
pairs(::NamedTuple) with 3 entries:
  :X => [1.19156 0.100793; -2.51973 -0.00197414; … ; -0.101607 1.15807; -1.5425…
  :β => [0.0718727, -0.51281]
  :y => [0.100793, -2.51973, 2.07481, 0.844223, 1.15807, -0.475159]

````



````julia
julia> truth.β
2-element Array{Float64,1}:
  0.07187269298745927
 -0.5128103336795292

````



````julia
julia> truth.y
6-element Array{Float64,1}:
  0.10079289135480324
 -2.5197330871745263
  2.0748097755419757
  0.8442227439533416
  1.158074626662026
 -0.47515878362112707

````





And now pretend we don't know `β`, and have the model figure it out.
Often these are easier to work with in terms of `particles` (built using [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl)):

````julia
julia> post = dynamicHMC(m(X=truth.X), (y=truth.y,));

julia> particles(post)
(β = Particles{Float64,1000}[0.538 ± 0.26, 0.775 ± 0.51],)

````





For model diagnostics and prediction, we need the _predictive distribution_:
````julia
julia> pred = predictive(m,:β)
@model (X, β) begin
        y ~ For(eachrow(X)) do x
                Normal(x' * β, 1)
            end
    end


````





This requires `X` and `β` as inputs, so we can do something like this to do a _posterior predictive check_

````julia
ppc = [rand(pred(;X=truth.X, p...)).y for p in post];

truth.y - particles(ppc)
````


````
6-element Array{Particles{Float64,1000},1}:
 -0.534 ± 0.55
 -1.28 ± 1.3
  0.551 ± 0.53
  0.918 ± 0.91
  0.624 ± 0.63
  0.534 ± 0.53
````





These play a role similar to that of residuals in a non-Bayesian approach (there's plenty more detail to go into, but that's for another time).

With some minor modifications, we can put this into a form that allows symbolic simplification:
````julia
julia> m2 = @model X begin
    N = size(X,1)
    k = size(X,2)
    β ~ Normal() |> iid(k)
    yhat = X * β
    y ~ For(N) do j
            Normal(yhat[j], 1)
        end
end;

julia> 
symlogpdf(m2)
                            N                                       k           
                           ___                                     ___          
                           ╲                                       ╲            
                            ╲                            2          ╲          2
-0.919⋅N - 0.919⋅k - 0.5⋅   ╱    (y[_j1] - 1.0⋅yhat[_j1])  - 0.5⋅   ╱    β[_j1] 
                           ╱                                       ╱            
                           ‾‾‾                                     ‾‾‾          
                         _j1 = 1                                 _j1 = 1        

````






We can use the symbolic simplification to speed up computations:

````julia
julia> using BenchmarkTools

julia> 
@btime logpdf($m2(X=X), $truth)
  1.958 μs (54 allocations: 1.27 KiB)
-15.84854642585797

julia> @btime logpdf($m2(X=X), $truth, $codegen)
  297.867 ns (5 allocations: 208 bytes)
-15.848600660220587

````





## What's Really Happening Here?

Under the hood, `rand` and `logpdf` specify different ways of "running" the model.

 `rand`  turns each `v ~ dist` into `v = rand(dist)`, finally outputting the `NamedTuple` of all values it has seen.

`logpdf` steps through the same program, but instead accumulates a log-density. It begins by initializing `_ℓ = 0.0`. Then at each step, it turns `v ~ dist` into `_ℓ += logpdf(dist, v)`, before finally returning `_ℓ`.

Note that I said "turns into" instead of "interprets". Soss uses [`GG.jl`](https://github.com/thautwarm/GG.jl) to generate specialized code for a given model, inference primitive (like `rand` and `logpdf`), and type of data.

This idea can be used in much more complex ways. `weightedSample` is a sort of hybrid between `rand` and `logpdf`. For data that are provided, it increments a `_ℓ` using `logpdf`. Unknown values are sampled using `rand`.

````julia
julia> ℓ, proposal = weightedSample(m(X=X), (y=truth.y,));

julia> ℓ
-33.647614702926504

julia> proposal.β
2-element Array{Float64,1}:
 -1.216679880035586
  0.42410088891060693

````





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
