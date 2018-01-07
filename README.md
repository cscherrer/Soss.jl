# Soss

Soss is a library for manipulating source-code representation of probabilistic models.

**Soss IS "PRE-ALPHA" SOFTWARE -- BREAKING CHANGES ARE IMMINENT**


Here's a simple linear regression model in Soss:

```julia
linReg1D = @model N begin
    # Priors chosen following Gelman(2008)
    α ~ Cauchy(0,10)
    β ~ Cauchy(0,2.5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    x ~ For(1:N) do n 
        Cauchy(0,100)
    end
    ŷ = α + β .* x
    y ~ For(1:N) do n 
        Normal(ŷ[n], σ)
    end
end
```

This produces a Julia expression representing a function:
```julia
:(function (N,)
        α ~ Cauchy(0, 10)
        β ~ Cauchy(0, 2.5)
        σ ~ Truncated(Cauchy(0, 3), 0, Inf)
        x ~ For(((n,)->Cauchy(0, 100)), 1:N)
        ŷ = α + β .* x
        y ~ For(((n,)->Normal(ŷ[n], σ)), 1:N)
    end)
```

Note that the notation after parsing can be slightly different than it originally entered.

Usually, we're not interested in the distribution on `x`, so we condition on it. This removes the distribution declaration, instead passing it as a parameter:

```julia
Main> lr2 = condition(linReg1D, :x)
:(function (N, x)
        α ~ Cauchy(0, 10)
        β ~ Cauchy(0, 2.5)
        σ ~ Truncated(Cauchy(0, 3), 0, Inf)
        ŷ = α + β .* x
        y ~ For(((n,)->Normal(ŷ[n], σ)), 1:N)
    end)
```

We need to be careful with `condition` in cases where the distribution depends on other random values. The implementation will eventually take this into account, but it doens't yet.

From here, we can "run the model" forward, specifying `x` and generating both the parameters and the `y` response. To instead "observe" the `y` values, we need a different approach that conditional. To `observe` a quantity means it is passed as an argument, but the value still affects the distribution:

```julia
Main> lr3 = observe(lr2, :y)
:(function (N, x, y)
        α ~ Cauchy(0, 10)
        β ~ Cauchy(0, 2.5)
        σ ~ Truncated(Cauchy(0, 3), 0, Inf)
        ŷ = α + β .* x
        y <~ For(((n,)->Normal(ŷ[n], σ)), 1:N)
    end)
```

After building a model, you can query it:

```julia
> parameters(lr3)
3-element Array{Symbol,1}:
 :α
 :β
 :σ

Main> supports(lr3)
Dict{Symbol,Any} with 3 entries:
  :α => Distributions.RealInterval(-Inf, Inf)
  :σ => Distributions.RealInterval(0.0, Inf)
  :β => Distributions.RealInterval(-Inf, Inf)
```


Or you can transform it to a form suitable for specialized inference algorithms. For example, a Stan-like approach:

(coming soon, here it is for a different model)
```julia
> logdensity(normalModel)
:(function (θ, DATA)
        ℓ = 0.0
        μ = θ[1]
        ℓ += logpdf(Normal(0, 5), μ)
        σ = softplus(θ[2])
        ℓ += abs(σ - θ[2])
        ℓ += logpdf(Truncated(Cauchy(0, 3), 0, Inf), σ)
        for x = DATA
            ℓ += logpdf(Normal(μ, σ), x)
        end
        return ℓ
    end)
```

## The name

* "Source" (the stuff transformed by Soss), said with a thick Northeastern accent
* Cockney rhyming slang ("sauce pan" rhymes with "[Stan](http://mc-stan.org/)")
* **S**oss is **O**pen **S**ource **S**oftware

