# Soss

Soss is a library for manipulating source-code representation of probabilistic models.

**SAUCE IS "PRE-ALPHA" SOFTWARE -- BREAKING CHANGES ARE IMMINENT**


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


## The name

* "Source" (the stuff transformed by Soss), said with a thick Northeastern accent
* Cockney rhyming slang ("sauce pan" rhymes with "[Stan](http://mc-stan.org/)")
* **S**oss is **O**pen **S**ource **S**oftware
