# # Example: Linear regression

# ## Defining the linear regression model

# Let's define our linear regression model:

using Soss
using Random

model = @model X begin
    p = size(X, 2) # `p` is the number of features
    α ~ Normal(0, 1) # `α` (alpha) is the intercept
    β ~ Normal(0, 1) |> iid(p) # `β` (beta) is the vector of coefficients
    σ ~ HalfNormal(1) # `σ` (sigma) is the dispersion parameter
    η = α .+ X * β # `η` (eta) is the linear predictor
    μ = η # `μ` (mu) is the expected value of `Y`
    y ~ For(eachindex(μ)) do j
        Normal(μ[j], σ)
    end
end;

# In Soss, models are _first-class_ and _function-like_, and applying a model to its arguments gives a _joint distribution_.

# Just a few of the things we can do in Soss:
# - Sample from the forward model
# - Condition a joint distribution on a subset of parameters
# - Have arbitrary Julia values (yes, even other models) as inputs or outputs of a model
# - Build a new model for the _predictive_ distribution, for assigning parameters to particular values

# ## Sampling from the forward model

# First, create some fake data:

X = randn(6,2)

# Now, sample from the forward model:

forward_sample = rand(model(X=X))

# The `pairs` function can make this a little easier to read:

pairs(forward_sample)

# ## Use MCMC to sample from the posterior distribution

# First, generate some fake data:

num_rows = 1_000
num_features = 2
X = randn(num_rows, num_features)

# Pick the true values for our coefficients `β`:

β_true = [2.0, -1.0]

# We also need to pick a true value for the intercept `α`:

α_true = 1.0

# And we also need to pick a true value for the dispersion parameter `σ`

σ_true = 0.5

# Now, generate the true labels:

η_true = α_true .+ X * β_true
μ_true = η_true
noise = randn(num_rows) .* σ_true
y_true = μ_true .+ noise

# Now we use MCMC (specifically, the No-U-turn sampler) to sample from the
# posterior distribution:

posterior = dynamicHMC(model(X=X), (y=y_true,))

# Often, the posterior distributions are easier to work with in terms of
# `particles` (built using [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl)):

particles(posterior)

# Again, the `pairs` function can make this a little easier to read:

pairs(particles(posterior))

# Compare the posterior distributions on `σ`, `α`, and `β` to the true values:

@show σ_true; @show α_true; @show β_true;

# We did a pretty good job at recovering the true parameter values!

# ## Construct the posterior predictive distribution

# For model diagnostics and prediction, we need the posterior _predictive distribution_:

posterior_predictive = predictive(model, :β)

# This requires `X` and `β` as inputs, so we can do something like this to do a _posterior predictive check (PPC)_

y_ppc = [rand(posterior_predictive(;X=X, p...)).y for p in posterior]

# We can compare the posterior predictive distribution on `y` to the true values of `y`:

y_true - particles(y_ppc)

# These play a role similar to that of residuals in a non-Bayesian approach (there's plenty more detail to go into, but that's for another time).

# ## So, what's really happening here?

# Under the hood, `rand` and `logpdf` specify different ways of "running" the model.

 # `rand`  turns each `v ~ dist` into `v = rand(dist)`, finally outputting the `NamedTuple` of all values it has seen.

# `logpdf` steps through the same program, but instead accumulates a log-density. It begins by initializing `_ℓ = 0.0`. Then at each step, it turns `v ~ dist` into `_ℓ += logpdf(dist, v)`, before finally returning `_ℓ`.

# Note that I said "turns into" instead of "interprets". Soss uses [`GG.jl`](https://github.com/thautwarm/GG.jl) to generate specialized code for a given model, inference primitive (like `rand` and `logpdf`), and type of data.

# This idea can be used in much more complex ways. `weightedSample` is a sort of hybrid between `rand` and `logpdf`. For data that are provided, it increments a `_ℓ` using `logpdf`. Unknown values are sampled using `rand`.

ℓ, proposal = weightedSample(model(X=X), (y=y_true,));

# `ℓ`:

ℓ

# `proposal.β`:

proposal.β

# Again, there's no runtime check needed for this. Each of these is compiled the first time it is called, so future calls are very fast. Functions like this are great to use in tight loops.
