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
function prune(m::Model, xs :: Symbol...; trim_args = true)
    po = poset(m) #Creates a new SimplePoset, so no need to copy before mutating

    newvars = variables(m)

    for x in xs
        setdiff!(newvars, above(po,x))
        setdiff!(newvars, [x])
    end

    # Keep arguments in newvars
    newargs = arguments(m) ∩ newvars
    setdiff!(newvars, newargs)

    if trim_args
        # keep arguments only if depended upon by newvars
        dependencies = mapfoldl(var -> below(po, var), vcat, newvars, init = Symbol[]) # mapfoldl needed since newvars can be empty
        newargs = dependencies ∩ newargs
    end

    theModule = getmodule(m)
    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(newvars; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end
