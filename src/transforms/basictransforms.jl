export prior

"""
    prior(m, xs...)

Returns the minimal model required to sample random variables `xs...`. Useful for extracting a prior distribution from a joint model `m` by designating `xs...` and the variables they depend on as the prior and hyperpriors.

# Example

```jldoctest
m = @model n begin
    α ~ Gamma()
    β ~ Gamma()
    θ ~ Beta(α,β)
    x ~ Binomial(n, θ)
end;
Soss.prior(m, :x)

# output
@model begin
        β ~ Gamma()
        α ~ Gamma()
        θ ~ Beta(α, β)
    end
```
"""
prior(m::Model, xs...) = fixargs(m, before(m, xs..., inclusive = false, strict = true))


export likelihood
"""
    likelihood(m, xs...)

Return a model with only the specified variables in the body. Required dependencies will be included as arguments.

"""
function likelihood(m::Model, xs...) 
    M = getmodule(m)
    result = foldl(merge, (Model(M, findStatement(m,x)) for x in xs))

    for x in xs
        for pa in parents(digraph(m), x)
            pa ∈ xs && continue
            result = merge(result, Model(M, Arg(pa)))
        end
    end

    return result
end

export prune

"""
    prune(m, xs...)

Returns a model transformed by removing `xs...` and all variables that depend on `xs...`. Unneeded arguments are also removed.

# Examples

```jldoctest
m = @model n begin
    α ~ Gamma()
    β ~ Gamma()
    θ ~ Beta(α,β)
    x ~ Binomial(n, θ)
end;
prune(m, :θ)

# output
@model begin
        β ~ Gamma()
        α ~ Gamma()
    end
```

```jldoctest
m = @model n begin
    α ~ Gamma()
    β ~ Gamma()
    θ ~ Beta(α,β)
    x ~ Binomial(n, θ)
end;
prune(m, :n)

# output
@model begin
        β ~ Gamma()
        α ~ Gamma()
        θ ~ Beta(α, β)
    end
```
"""
prune(m::Model, xs...) = fixargs(m, before(m, xs..., inclusive = false, strict = false))


export predictive
"""
    predictive(m, xs...)

Returns a model transformed by adding `xs...` to arguments with a body containing only statements that depend on `xs`, or statements that are depended upon by children of `xs` through an open path. Unneeded arguments are trimmed.

# Examples
```jldoctest
m = @model (n, k) begin
    β ~ Gamma()
    α ~ Gamma()
    θ ~ Beta(α, β)
    x ~ Binomial(n, θ)
    z ~ Binomial(k, α / (α + β))
end;
predictive(m, :θ)

# output
@model (n, θ) begin
        x ~ Binomial(n, θ)
    end
```

"""
@inline predictive(m::Model, xs...) = _predictive(m, namedtuple(xs))
# predictive(m::Model, xs...) = after(m, xs..., strict = true)

@generated function _predictive(m::Model, ::Type{NT}) where {NT<:NamedTuple}
    m = type2model(m)
    return fixargs(m, after(m, getntkeys(NT)...; strict=true))
end

export Do
"""
    Do(m, xs...)

Returns a model transformed by adding `xs...` to arguments. The remainder of the body remains the same, consistent with Judea Pearl's "Do" operator. Unneeded arguments are trimmed.

# Examples
```jldoctest
m = @model (n, k) begin
    β ~ Gamma()
    α ~ Gamma()
    θ ~ Beta(α, β)
    x ~ Binomial(n, θ)
    z ~ Binomial(k, α / (α + β))
end;
Do(m, :θ)

# output
@model (n, k, θ) begin
        β ~ Gamma()
        α ~ Gamma()
        x ~ Binomial(n, θ)
        z ~ Binomial(k, α / (α + β))
    end
```

"""
Do(m::Model, xs...) = fixargs(m, after(m, xs..., strict = false))
