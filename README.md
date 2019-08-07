# Soss

Soss is a Julia library for _probabilistic metaprogramming_. 

The job of any statistical or machine learning model is to impose some structure on observed data, to provide a way of reasoning about it. In probabilistic programming, this structure is the specification of a _generative process_ hypothesized to describe the origin of the data.

We can think of this as a program that makes some random choices along the way. These eventually lead to some observed result, which we hope to use to reason about the choices made along the way.

Say we invite a friend over for dinner. There are two routes the friend might take. One is usually slightly faster, but crosses a drawbridge that sometimes leads to a long wait. If our friend is very late, we might say, “They probably got stuck waiting for the bridge.” We’re using an observation (our friend is late) to reason about the outcome of a random process (the bridge was up).

**A primary goal of probabilistic programming is to separate _modeling_ from _inference_.** 

The model is an abstraction of a program, and describes some relationships among random unobserved *parameters*, and between these and the observed data. But it doesn’t tell us anything about _how_ to get from the observed data.

For that, we need _inference_. An inference algorithm takes a model and (for some models) observed data, and gives us information about the distribution of the parameters, _conditional_ on the observed data.

For a simple example, say we have flip a coin `n` times and observe `k` heads. If we have no preconceptions about the probability of heads (a strange assumption, but let’s go with it), we could model this as

```julia
julia> coin = @model n,k begin
    p ~ Uniform()
    k ~ Binomial(n,p)
end
```

There are lots of inference algorithms we could use to think of this. The simplest is _rejection sampling_. In many cases, this is too slow for practical use. But it gives a relatively simple way to think of a model, so it’s a good place to start.

Rejection sampling looks like this:

1. Start with `n` and `k`
2. Sample `p` from a `Uniform` distribution
3. Sample a new `k` from a `Binomial` distribution
4. If `k` matches, keep this sample. Otherwise, reject it and start over



## Quick Start

Back to our example

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

Let’s make some fake data:

```julia
julia> x = randn(100);
julia> y = 3 .* x .+ randn(100);
```

```julia
julia> nuts(linReg1D, (x=x, y=y)) |> particle
s
MCMC, adapting ϵ (75 steps)
7.7e-5 s/step ...done
MCMC, adapting ϵ (25 steps)
0.00011 s/step ...done
MCMC, adapting ϵ (50 steps)
0.00011 s/step ...done
MCMC, adapting ϵ (100 steps)
0.00017 s/step ...done
MCMC, adapting ϵ (200 steps)
0.00011 s/step ...done
MCMC, adapting ϵ (400 steps)
0.0001 s/step ...done
MCMC, adapting ϵ (50 steps)
0.00013 s/step ...done
MCMC (1000 steps)
0.00012 s/step ...done
(α = -0.0269 ± 0.097, β = 2.91 ± 0.1, σ = 0.994 ± 0.069)
```