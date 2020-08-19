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
end
````





In Soss, models are _first-class_ and _function-like_, and applying a model to its arguments gives a _joint distribution_.

Just a few of the things we can do in Soss:

- Sample from the (forward) model
- Condition a joint distribution on a subset of parameters
- Have arbitrary Julia values (yes, even other models) as inputs or outputs of a model
- Build a new model for the _predictive_ distribution, for assigning parameters to particular values

Let's use our model to build some fake data:
````julia
julia> import Random; Random.seed!(3)
Random.MersenneTwister(UInt32[0x00000003], Random.DSFMT.DSFMT_state(Int32[-1359582567, 1073454075, 1934390716, 1073583786, -114685834, 1073112842, -1913218479, 1073122729, -73577195, 1073266439  …  1226759590, 1072980451, -1366384707, 1073012992, 1661148031, 2121090155, 141576524, -658637225, 382, 0]), [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], UInt128[0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000  …  0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000, 0x00000000000000000000000000000000], 1002, 0)

julia> X = randn(6,2)
6×2 Matrix{Float64}:
  1.19156    0.100793
 -2.51973   -0.00197414
  2.07481    1.00879
 -0.97325    0.844223
 -0.101607   1.15807
 -1.54251   -0.475159

````



````julia
julia> truth = rand(m(X=X));
(β = [0.07187269298745927, -0.5128103336795292], y = [-1.5462858466884173, 0.33157118320250245, -1.07546820508531, -1.6689735918627429, -1.0335681260821046, -0.5761553015966487])

julia> pairs(truth)
pairs(::NamedTuple) with 2 entries:
  :β => [0.0718727, -0.51281]
  :y => [-1.54629, 0.331571, -1.07547, -1.66897, -1.03357, -0.576155]

````



````julia
julia> truth.β
2-element Vector{Float64}:
  0.07187269298745927
 -0.5128103336795292

````



````julia
julia> truth.y
6-element Vector{Float64}:
 -1.5462858466884173
  0.33157118320250245
 -1.07546820508531
 -1.6689735918627429
 -1.0335681260821046
 -0.5761553015966487

````





And now pretend we don't know `β`, and have the model figure it out.
Often these are easier to work with in terms of `particles` (built using [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl)):

````julia
julia> post = dynamicHMC(m(X=X), (y=truth.y,));
1000-element Vector{NamedTuple{(:β,),Tuple{Vector{Float64}}}}:
 (β = [0.20409988733534754, -1.01867552189848],)
 (β = [0.10106630247717097, -0.7494142948039466],)
 (β = [-0.138319627899054, -0.36159991654298423],)
 (β = [0.3105209880513822, -1.6090416251219788],)
 (β = [-0.13805713169775496, -0.9701497626140632],)
 (β = [0.12050989043494814, -0.7885707464526038],)
 (β = [-0.15664947720253414, -0.6573135582173841],)
 (β = [-0.42789225662841907, -1.0496819817876257],)
 (β = [-0.28396888149100596, -0.9780544278380506],)
 (β = [0.021974008994914862, -0.19812982922559214],)
 ⋮
 (β = [0.13653109358657714, -0.47631912806837207],)
 (β = [-0.3208972832298396, -1.054015046592049],)
 (β = [0.09909298312926401, -0.4488680864432285],)
 (β = [-0.14876052437118045, -0.920579800082227],)
 (β = [-0.34149209191540336, -0.739296121217693],)
 (β = [0.1035064485555062, -0.45535756632260177],)
 (β = [-0.14851675100659356, -0.33376910993471964],)
 (β = [-0.01108288292338655, -0.7075473023399144],)
 (β = [0.11182874588674081, -1.4766090812408703],)

julia> particles(post)
(β = MonteCarloMeasurements.Particles{Float64,1000}[-0.0484 ± 0.26, -0.793 ± 0.52],)

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

ppc = [rand(pred(;X=X, p...)).y for p in post];

truth.y - particles(ppc)
````


````
6-element Vector{MonteCarloMeasurements.Particles{Float64,1000}}:
 -1.35 ± 1.0
  0.252 ± 1.2
 -0.202 ± 1.2
 -1.05 ± 1.2
 -0.104 ± 1.2
 -0.998 ± 1.1
````





These play a role similar to that of residuals in a non-Bayesian approach (there's plenty more detail to go into, but that's for another time).

With some minor modifications, we can put this into a form that allows symbolic simplification:
````julia

m2 = @model X begin
    N = size(X,1)
    k = size(X,2)
    β ~ Normal() |> iid(k)
    yhat = X * β
    y ~ For(N) do j
            Normal(yhat[j], 1)
        end
end;

symlogpdf(m2).evalf(3)
````





[the `evalf(3)` is to reduce the displayed number of decimal positions]

We can use the symbolic simplification to speed up computations:

````julia
julia> using BenchmarkTools

julia> jointdist = m2(X=X)
Joint Distribution
    Bound arguments: [X]
    Variables: [k, β, yhat, N, y]

@model X begin
        k = size(X, 2)
        β ~ Normal() |> iid(k)
        yhat = X * β
        N = size(X, 1)
        y ~ For(N) do j
                Normal(yhat[j], 1)
            end
    end


julia> @btime logpdf($jointdist, $truth)
  2.845 μs (38 allocations: 864 bytes)
-10.139853153922688

julia> @btime logpdf($jointdist, $truth, $codegen)
  139.812 ns (1 allocation: 128 bytes)
-10.139853153922687

````





## What's Really Happening Here?

Under the hood, `rand` and `logpdf` specify different ways of "running" the model.

 `rand`  turns each `v ~ dist` into `v = rand(dist)`, finally outputting the `NamedTuple` of all values it has seen.

`logpdf` steps through the same program, but instead accumulates a log-density. It begins by initializing `_ℓ = 0.0`. Then at each step, it turns `v ~ dist` into `_ℓ += logpdf(dist, v)`, before finally returning `_ℓ`.

Note that I said "turns into" instead of "interprets". Soss uses [`GG.jl`](https://github.com/thautwarm/GG.jl) to generate specialized code for a given model, inference primitive (like `rand` and `logpdf`), and type of data.

This idea can be used in much more complex ways. `weightedSample` is a sort of hybrid between `rand` and `logpdf`. For data that are provided, it increments a `_ℓ` using `logpdf`. Unknown values are sampled using `rand`.

````julia
julia> ℓ, proposal = weightedSample(m(X=X), (y=truth.y,));
(-10.094135139337315, (X = [1.1915557734285787 0.10079289135480324; -2.5197330871745263 -0.0019741367391015213; … ; -0.1016067940589428 1.158074626662026; -1.5425131978228126 -0.47515878362112707], β = [-0.6118607888077296, -0.6489424142398419], y = [-1.5462858466884173, 0.33157118320250245, -1.07546820508531, -1.6689735918627429, -1.0335681260821046, -0.5761553015966487]))

julia> ℓ
-10.094135139337315

julia> proposal.β
2-element Vector{Float64}:
 -0.6118607888077296
 -0.6489424142398419

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

We are working on the
[SossMLJ](https://github.com/cscherrer/SossMLJ.jl)
package, which will provide an interface between Soss and the
[MLJ](https://github.com/alan-turing-institute/MLJ.jl)
machine learning framework.

## Stargazers over time

[![Stargazers over time](https://starchart.cc/cscherrer/Soss.jl.svg)](https://starchart.cc/cscherrer/Soss.jl)
