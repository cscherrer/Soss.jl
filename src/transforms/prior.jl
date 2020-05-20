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
    po = poset(m) #Creates a new SimplePoset, so no need to copy before mutating

    newvars = collect(xs)

    for x in xs
        append!(newvars, below(po,x))
    end

    newargs = arguments(m) ∩ newvars
    setdiff!(newvars, newargs)

    theModule = getmodule(m)
    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(newvars; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end
