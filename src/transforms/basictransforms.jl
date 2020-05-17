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
prior(m, :θ)

# output
@model begin
        β ~ Gamma()
        α ~ Gamma()
        θ ~ Beta(α, β)
    end
```
"""
function prior(m::Model, xs...)
    variables = belowvars(m, xs...)
    return assemblefrom(m, variables, arguments(m) ∩ variables)
end

export prune

"""
    prune(m, xs...; trim_args = true)

Returns a model transformed by removing `xs...` and all variables that depend on `xs...`. If `trim_args = true`, unneeded arguments are also removed. Use `trim_args = false` to leave arguments unaffected.

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
function prune(m::Model, xs...; trim_args = true)
    variables = notabovevars(m, xs...; inclusive = false)
    return assemblefrom(m, variables, variables ∩ arguments(m), trim_args = trim_args)
end

export Do
function Do(m::Model, xs...; trim_args = false)
    args = arguments(m) ∪ xs
    variables = abovevars(m, args...; inclusive = true)
    return assemblefrom(m, variables, args, trim_args = trim_args)
end

Do(m::Model; kwargs...) = Do(m,keys(kwargs)...)(;kwargs...)

export predictive
predictive(m::Model, xs...) = Do(m::Model, xs...; trim_args = true)

function belowvars(m::Model, xs...; inclusive = true)
    po = poset(m)
    vars = inclusive ? collect(xs) : Symbol[]
    for x in xs
        append!(vars, below(po, x))
    end
    return unique!(vars)
end

notbelowvars(m::Model, xs...; inclusive = false) = setdiff(variables(m), belowvars(m, xs...; inclusive = !inclusive))

function abovevars(m::Model, xs...; inclusive = false)
    po = poset(m)
    vars = inclusive ? collect(xs) : Symbol[]
    for x in xs
        append!(vars, above(po, x))
    end
    return unique!(vars)
end

notabovevars(m::Model, xs...; inclusive = true) = setdiff(variables(m), abovevars(m, xs...; inclusive = !inclusive))

function assemblefrom(m::Model, vars, args; trim_args = false)
    params = setdiff(vars, args)
    if trim_args
        args = belowvars(m, args...) ∩ belowvars(m, params...)
    end
    theModule = getmodule(m)
    m_init = Model(theModule, args, NamedTuple(), NamedTuple(), nothing)
    m = foldl(params; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
    return m
end
