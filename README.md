# Soss

Soss is a Julia library for _probabilistic metaprogramming_. 

The job of any statistical or machine learning model is to impose some structure on observed data, to provide a way of reasoning about it. In probabilistic programming, this structure is the specification of a _generative process_ hypothesized to describe the origin of the data.

We can think of this as a program that makes some random choices along the way. These eventually lead to some observed result, which we hope to use to reason about the choices made along the way.

Say we invite a friend over for dinner. There are two routes the friend might take. One is usually slightly faster, but crosses a drawbridge that sometimes leads to a long wait. If our friend is very late, we might say, “They probably got stuck waiting for the bridge.” We’re using an observation (our friend is late) to reason about the outcome of a random process (the bridge was up).

**A primary goal of probabilistic programming is to separate _modeling_ from _inference_.** 

The model is an abstraction of a program, and describes some relationships among random unobserved *parameters*, and between these and the observed data. But it doesn’t tell us anything about _how_ to get from the observed data.

For that, we need _inference_. An inference algorithm takes a model and (for some models) observed data, and gives us information about the distribution of the parameters, _conditional_ on the observed data.

## Rejection Sampling

For a simple example, say we have flip a coin `n` times and observe `k` heads. If we have no preconceptions about the probability of heads (a strange assumption, but let’s go with it), we could model this as

```julia
julia> coin = @model n,k begin
    p ~ Uniform()
    k ~ Binomial(n,p)
end
```

Like most probabilistic programs, this represents observations (`k`) as being generated from parameters (`p`), though the observations are also known in advance and are passed in as parameters. The idea is that this constraint on the observations propagates to the parameters, 

There are lots of inference algorithms we could use to think of this. The simplest is _rejection sampling_. In many cases, this is too slow for practical use. But it gives a relatively simple way to think of a model, so it’s a good place to start.

Rejection sampling looks like this:

1. Start with `n` and `k`
2. Sample `p` from a `Uniform` distribution
3. Sample a new `k` from a `Binomial` distribution
4. If `k` matches, keep this sample. Otherwise, reject it and start over

```julia
julia> r = rejection(coin);
julia> r((n=10,k=3))
(n = 10, k = 3, p = 0.47778603607779724)
```

Let's do this lots of times and take only the `p` samples, gathering them into `Particles`:
```julia
julia> post = [r((n=10,k=3)).p for j in 1:1000] |> Particles
Part1000(0.3315 ± 0.132)
```

This is clearly different from the `Uniform` we started with. What if we had the same proportion of heads but 100× as many samples?

```julia
julia> post = [r((n=1000,k=300)).p for j in 1:1000] |> Particles
Part1000(0.3006 ± 0.0144)
```

From statistics, we should expect the standard deviation to be ¹/₁₀ the original. The relationship would be more precise if we took a larger number of particles (at the cost of more computational resources).


## No U-Turn Sampling

The simple rejection sampling approach described above is great for discrete data with very few possibilities, but it doesn't scale. Let's consider a more typical model, Bayesian linear regression. There are a few ways to write this; here's a relatively simple approach:

```julia
julia> linReg1D = @model (x, y) begin
    α ~ Cauchy(0, 10)
    β ~ Cauchy(0, 2.5)
    σ ~ HalfCauchy(3)
    ŷ = α .+ β .* x
    N = length(x)
    y ~ For(1:N) do n
            Normal(ŷ[n], σ)
        end
end
```

Now let’s make some fake data:

```julia
julia> x = randn(100);
julia> y = 3 .* x .+ randn(100);
```

Now we can fit with the _No U-Turn Sampler_ ("NUTS")

```julia
julia> post = nuts(linReg1D, (x=x, y=y)) |> particles
MCMC, adapting ϵ (75 steps)
8.1e-5 s/step ...done
MCMC, adapting ϵ (25 steps)
8.9e-5 s/step ...done
MCMC, adapting ϵ (50 steps)
0.00012 s/step ...done
MCMC, adapting ϵ (100 steps)
8.5e-5 s/step ...done
MCMC, adapting ϵ (200 steps)
7.1e-5 s/step ...done
MCMC, adapting ϵ (400 steps)
7.2e-5 s/step ...done
MCMC, adapting ϵ (50 steps)
0.00077 s/step ...done
MCMC (1000 steps)
8.2e-5 s/step ...done
(α = -0.0489 ± 0.1, β = 2.99 ± 0.086, σ = 0.984 ± 0.074)
```