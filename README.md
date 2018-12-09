# Soss

Soss is a Julia library for _probabilistic metaprogramming_. Before we get into that, let’s have a look at a simple example:

```julia
hello = @model μ,x begin
    σ ~ HalfCauchy()
    x ⩪ Normal(μ,σ) |> iid
end
```

Soss considers three kinds of variables:

- _Free variables_ are given as inputs at the beginning of the model, and are not constrained by any distribution. In `hello`, `μ` is a free variable.
- _Parameters_ are considered as being drawn from some distribution. In the above example, `σ` is drawn from a `HalfCauchy` distribution. Generally parameters will have a prior distribution specified, but won’t have any associated observed data available.
- _Observed variables_ are associate data with some distribution, which is usually expressed as a function of some parameters. In modeling terms, observed variables give a way of specifying the likelihood. In the example above, `x` is a vector, and `iid` indicates that the values in `x` are _independent, and identically distributed_.

Soss makes it easy to query these different variable subsets for a given model:

```julia
julia> freeVariables(hello)
1-element Array{Symbol,1}:
 :μ

julia> parameters(hello)
1-element Array{Symbol,1}:
 :σ

julia> observed(hello)
1-element Array{Symbol,1}:
 :x
```

There are also unions of these

```julia
julia> variables(hello)
3-element Array{Symbol,1}:
 :μ
 :σ
 :x

julia> arguments(hello)
2-element Array{Symbol,1}:
 :μ
 :x

julia> stochastic(hello)
2-element Array{Any,1}:
 :σ
 :x
```

## Model Manipulations

In some cases, we may want to specify a value once and for all:

```julia
julia> hello
@model (μ, x) begin
    σ ~ HalfCauchy()
    x ⩪ Normal(μ, σ) |> iid
end


julia> hello(μ=3.0)
@model (x,) begin
    μ = 3.0
    σ ~ HalfCauchy()
    x ⩪ Normal(μ, σ) |> iid
end
```

In Bayesian modeling, we usually work in terms of a _prior_ distribution on the parameters, and a _likelihood_ that gives the probability of the data for a given assignment of those parameters. It’s sometimes of value to separate these two; Soss makes this easy too:

```julia
julia> prior(hello)
@model (μ,) begin
    σ ~ HalfCauchy()
end

julia> likelihood(hello)
@model (μ, σ) begin
    x ~ Normal(μ, σ) |> iid
end
```

Note that the arguments are added or removed, as needed. 

## Sampling from the posterior

Any inference algorithm is possible in Soss. So far, the _No U-Turn Sampler_ (NUTS) is implemented (thanks to Tamas Papp’s [DynamicHMC.jl](https://github.com/tpapp/DynamicHMC.jl))

```julia
julia> posterior = nuts(hello, data=(x=randn(10000),)).samples
1000-element Array{NamedTuple{(:μ, :σ),Tuple{Float64,Float64}},1}:
 (μ = -0.016750250341334094, σ = 1.0269802073542134) 
 (μ = -0.008405510241302977, σ = 1.0167021756621375) 
 (μ = -0.015574923802842802, σ = 1.0171769791897423) 
 (μ = -0.013021593156077087, σ = 1.0184344558003013) 
 (μ = -0.01780477236109085, σ = 1.0131727185064554)  
 (μ = -0.032662131300842695, σ = 1.0153176322142905) 
 (μ = -0.019576842879711565, σ = 1.0046042202153795) 
 (μ = -0.010861251137647089, σ = 1.0132758259829258) 
 (μ = -0.010390367753548568, σ = 1.0197606285893195) 
 (μ = -0.006956586470160837, σ = 1.020321342370646)  
 (μ = -0.026570215043822204, σ = 1.0179981689741073) 
 (μ = 0.0038200696879123327, σ = 1.0101621107293388) 
 (μ = 0.002818646907138813, σ = 1.0267531341033773)  
 (μ = -0.00929115068028712, σ = 1.0023324944611351)  
 ⋮                                                   
 (μ = -0.013539165964585525, σ = 1.0251881958130318) 
 (μ = -0.006739442336510352, σ = 1.0104953775322774) 
 (μ = -0.016820178082252172, σ = 1.0143872288565643) 
 (μ = -0.0015472822264999296, σ = 1.0106951232174335)
 (μ = -0.02395361215610855, σ = 0.9986872414407054)  
 (μ = -0.022213309614302235, σ = 0.9990999963876895) 
 (μ = -0.01986363495451096, σ = 1.0025106436071947)  
 (μ = -0.017228865956048067, σ = 1.0039663584854361) 
 (μ = -0.019226211417814627, σ = 1.002473160705432)  
 (μ = -0.0027371172635497665, σ = 1.0274537663874084)
 (μ = -0.007280591268333988, σ = 1.0164054485543828) 
 (μ = -0.0183919608566083, σ = 1.0173829850337315)   
 (μ = -0.010839639031948869, σ = 1.0142045654219038) 
 (μ = -0.010839639031948869, σ = 1.0142045654219038) 

julia> quantile(getfield.(posterior, :μ),[0.05,0.5,0.95])
3-element Array{Float64,1}:
 -0.028852616723869018
 -0.011706194283494295
  0.004090681140149757

```



## Dependency Graphs

```julia
julia> graphEdges(hello)
2-element Array{Pair{Symbol,Symbol},1}:
 :μ => :x
 :σ => :x
```

Great for more complex models:

```julia
julia> lda
@model (α, N, K, V, η) begin
    M = length(N)
    β ~ Dirichlet(repeat([η], V)) |> iid(K)
    θ ~ Dirichlet(repeat([α], K)) |> iid(M)
    z ~ For(1:M) do m
            Categorical(θ[m]) |> iid(N[m])
        end
    w ⩪ For(1:M) do m
            For(1:N[m]) do n
                Categorical(β[(z[m])[n]])
            end
        end
end

julia> graphEdges(lda)
14-element Array{Pair{Symbol,Symbol},1}:
 :α => :θ
 :N => :w
 :N => :M
 :N => :z
 :M => :w
 :M => :z
 :M => :θ
 :K => :β
 :K => :θ
 :V => :β
 :z => :w
 :β => :w
 :η => :β
 :θ => :z
```

## Coming Soon

Since its initial Stan implementation, "Automatic Differentiation Variational Inference (ADVI)" has become a popular approach to approximate inference. This involves transforming parameters to be over R^n and approximating the posterior with a multivariate normal distribution. There are typically two options for this:

- The covariance can be a diagonal matrix, so the components of the distribution are independent. This is computationally efficient, but is very constrained, and often leads to dramatic underestimation of the variance.
- The covariance can be unconstrained - the only requirement in this case is that it be positive definite. This can result in much tighter bound and a better approximation, but with a great computational expense (quadratic in the dimension of the parameter space).

There's a middle ground that (to my knowledge) has not been explored. The log-likelihood is a function of the parameters that takes the form of a sum of expressions, each involving a subset of the parameters. 

Now, for a multivariate normal, the inverse of the covariance has an interesting property. An element Sigma_ij of this is zero if and only x_i and x_j are independent, given x_{k | k not  in {i,j}}. And this conditional independence property is equivalent to "x_i and x_j do not occur together in any term of the log-likelihood".

Because we're working in terms of expressions, we can get our hands on this relation and use it to specify the form of the inverse covariance. This will allow representation equivalent to the unconstrained version, at greatly reduced computational cost.

This isn't the whole story - to "do it right" would reduce the cost even more but require a different representation. Details of that approach are [here](https://ac.els-cdn.com/S0047259X98917456/1-s2.0-S0047259X98917456-main.pdf?_tid=01eafbd5-e4ce-4b29-bc98-47dfacf99cf2&acdnat=1537155460_c2081b7161fb58932c1551173b5140d5).

- Macro optimization of densities, as in [Passage](https://www.dropbox.com/s/zg2g0cfiin0jdmr/Scherrer%20et%20al.%20-%202014%20-%20Passage%20A%20Parallel%20Sampler%20Generator%20for%20Hierarchical%20Bayesian%20Modeling.pdf)
- Optimization based on exponential families, see [here](https://www.dropbox.com/s/26omxn6zo8gia3u/Scherrer%20-%20Unknown%20-%20An%20Exponential%20Family%20Basis%20for%20Probabilistic%20Programming.pdf?dl=0)

------

Stuff below this point is outdated, updates coming soon

## Old Docs

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

(works for older implementation, but for now this is just a mockup) 

```julia
> logdensity(lr3)
:(function ((N,x,y), θ)
        ℓ = 0.0
        α = θ[1]
        ℓ += logpdf(Cauchy(0, 10), α)
        β = θ[2]
        ℓ += logpdf(Cauchy(0, 2.5), β)
        σ = softplus(θ[3])
        ℓ += abs(σ - θ[3])
        ℓ += logpdf(Truncated(Cauchy(0, 3), 0, Inf), σ)
        ŷ = α + β .* x
        ℓ += logpdf(For(((n,)->Normal(ŷ[n], σ)), 1:N), y)
        return ℓ
    end)
```

## The name

- "Source" (the stuff transformed by Soss), said with a thick Northeastern accent
- Cockney rhyming slang ("sauce pan" rhymes with "[Stan](http://mc-stan.org/)")
- **S**oss is **O**pen **S**ource **S**oftware
