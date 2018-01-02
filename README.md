# Soss

Soss is a library for manipulating source-code representation of probabilistic models.

**Soss IS "PRE-ALPHA" SOFTWARE -- BREAKING CHANGES ARE IMMINENT**


Here's a very simple model in Soss:

```julia
normalModel = quote
    μ ~ Normal(0,5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    for x in DATA
        x <~ Normal(μ,σ)
    end
end
```

This is just a Julia expresion, with a few quirks:

* Parameter distributions are specified with `~`
* Observed data are specified with the keyword `DATA`, and given distributions using `<~`

After building a model, you can query it:

```julia
> parameters(normalModel)
2-element Array{Symbol,1}:
 :μ
 :σ

> supports(normalModel)
Dict{Symbol,Any} with 2 entries:
  :μ => Distributions.RealInterval(-Inf, Inf)
  :σ => Distributions.RealInterval(0.0, Inf)
```

You can decide to pass one of the parameters as a function argument:

```julia
> func(normalModel, :σ)
:(σ->begin
            μ ~ Normal(0, 5)
            for x = DATA
                x < ~(Normal(μ, σ))
            end
        end)
```

Or you can transform it to a form suitable for specialized inference algorithms. For example, a Stan-like approach:

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

