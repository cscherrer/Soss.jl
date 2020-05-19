function assemblefrom2(m::Model, params, args)
    theModule = getmodule(m)
    m_init = Model(theModule, args, NamedTuple(), NamedTuple(), nothing)
    m = foldl(params; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
    return m
end

function trim_args!(args, m, params)
    g = digraph(m)
    intersect!(args, vcat((parents(g, p) for p in params)...))
end

export before
function before(m::Model, xs...; inclusive = true, strict = true, trim_args = true)
    vars = strict ? belowvars(m, xs..., inclusive = inclusive) : notabovevars(m, xs..., inclusive = inclusive)
    args = arguments(m) ∩ vars
    params = setdiff(vars, args)
    if trim_args
        trim_args!(args, m, params)
    end
    return assemblefrom2(m, params, args)
end

export after
function after(m::Model, xs...; strict = true, trim_args = true)
    args = notabovevars(m, xs..., inclusive = true)
    params = strict ? abovevars(m, xs...; inclusive = false) : setdiff(notbelowvars(m, xs...; inclusive = false), arguments(m))
    if trim_args
        trim_args!(args, m, params)
    end
    return assemblefrom2(m, params, args)
end

# My prior
myprior(m, xs...) = before(m, xs..., inclusive = true, strict = true, trim_args = true)

# Chad's prior
chadprior(m, xs...) = before(m, xs..., inclusive = false, strict = true, trim_args = true)
"""
julia> Soss.chadprior(m, :θ)
@model begin
        β ~ Gamma()
        α ~ Gamma()
    end


julia> Soss.chadprior(m, :x)
@model begin
        β ~ Gamma()
        α ~ Gamma()
        θ ~ Beta(α, β)
    end
"""

mylikelihood(m, xs...) = after(m, xs..., inclusive = true, strict = false, trim_args = true)

chadlikelihood(m, xs...) = after(m, xs..., inclusive = false, strict = true, trim_args = true)
