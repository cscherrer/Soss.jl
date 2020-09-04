# # Example: Linear Model

# Let's jump right in with a simple linear model:

using Soss

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
end

# In Soss, models are _first-class_ and _function-like_, and applying a model to its arguments gives a _joint distribution_.

# Just a few of the things we can do in Soss:
#
# - Sample from the (forward) model
# - Condition a joint distribution on a subset of parameters
# - Have arbitrary Julia values (yes, even other models) as inputs or outputs of a model
# - Build a new model for the _predictive_ distribution, for assigning parameters to particular values

# Let's use our model to build some fake data:

import Random

Random.seed!(3)
X = randn(6,2)
truth = rand(m(X=X))
pairs(truth)

# Look at the true coefficients:

truth.β

# Look at the true labels:

truth.y

# And now pretend we don't know `β`, and have the model figure it out.

post = dynamicHMC(m(X=X), (y=truth.y,))

# Often these are easier to work with in terms of `particles` (built using [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl)):

particles(post)

# For model diagnostics and prediction, we need the _predictive distribution_:

pred = predictive(m,:β)

# This requires `X` and `β` as inputs, so we can do something like this to do a _posterior predictive check_

ppc = [rand(pred(;X=X, p...)).y for p in post]
truth.y - particles(ppc)

# These play a role similar to that of residuals in a non-Bayesian approach (there's plenty more detail to go into, but that's for another time).

# With some minor modifications, we can put this into a form that allows symbolic simplification: [the `evalf(3)` is to reduce the displayed number of decimal positions]

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

# We can use the symbolic simplification to speed up computations:

using BenchmarkTools

jointdist = m2(X=X)

@model X begin
    k = size(X, 2)
    β ~ Normal() |> iid(k)
    yhat = X * β
    N = size(X, 1)
    y ~ For(N) do j
        Normal(yhat[j], 1)
    end
end

# Without symbolic simplification:

@btime logpdf($jointdist, $truth)

# With symbolic simplification:

@btime logpdf($jointdist, $truth, $codegen)

# What's Really Happening Here?

# Under the hood, `rand` and `logpdf` specify different ways of "running" the model.

 # `rand`  turns each `v ~ dist` into `v = rand(dist)`, finally outputting the `NamedTuple` of all values it has seen.

# `logpdf` steps through the same program, but instead accumulates a log-density. It begins by initializing `_ℓ = 0.0`. Then at each step, it turns `v ~ dist` into `_ℓ += logpdf(dist, v)`, before finally returning `_ℓ`.

# Note that I said "turns into" instead of "interprets". Soss uses [`GG.jl`](https://github.com/thautwarm/GG.jl) to generate specialized code for a given model, inference primitive (like `rand` and `logpdf`), and type of data.

# This idea can be used in much more complex ways. `weightedSample` is a sort of hybrid between `rand` and `logpdf`. For data that are provided, it increments a `_ℓ` using `logpdf`. Unknown values are sampled using `rand`.

ℓ, proposal = weightedSample(m(X=X), (y=truth.y,));

# `ℓ`:

ℓ

# `proposal.β`:

proposal.β

# Again, there's no runtime check needed for this. Each of these is compiled the first time it is called, so future calls are very fast. Functions like this are great to use in tight loops.
