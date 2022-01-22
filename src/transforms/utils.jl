using SimpleGraphs: vlist, elist, out_neighbors

# Type piracy, this should really go in SimpleGraphs
# OTOH there's not anything else this could really mean
# function SimpleGraphs.components(g::SimpleDigraph)
#     SimpleGraphs.components(convert(SimpleGraph, g))
# end

function _before(g::SimpleDigraph, v)
    parents = in_neighbors(g, v)
    for i in parents
        append!(parents, _before(g, i))
    end
    return parents
end

before(g::SimpleDigraph, v; inclusive = true) = inclusive ? push!(_before(g, v), v) : _before(g, v)
function before(g::SimpleDigraph, vs...; inclusive = true)
    parents = inclusive ? collect(vs) : Symbol[]
    for v in vs
        append!(parents, before(g, v, inclusive = inclusive))
    end
    if !inclusive
        setdiff!(parents, vs)
    end
    return unique!(parents)
end

notbefore(g::SimpleDigraph, vs...; inclusive = false) = setdiff(vlist(g), before(g, vs...; inclusive = !inclusive))

function _after(g::SimpleDigraph, v)
    children = out_neighbors(g, v)
    for i in children
        append!(children, _after(g, i))
    end
    return children
end

after(g::SimpleDigraph, v; inclusive = true) = inclusive ? push!(_after(g, v), v) : _after(g, v)

function after(g::SimpleDigraph, vs...; inclusive = true)
    children = inclusive ? collect(vs) : Symbol[]
    for v in vs
        append!(children, after(g, v, inclusive = inclusive))
    end
    if !inclusive
        setdiff!(children, vs)
    end
    return unique!(children)
end

notafter(g::SimpleDigraph, vs...; inclusive = false) = setdiff(vlist(g), after(g, vs...; inclusive = !inclusive))

function assemblefrom(m::DAGModel, params, args)
    theModule = getmodule(m)
    m_init = DAGModel(theModule, args, NamedTuple(), NamedTuple(), nothing)
    m = foldl(params; init=m_init) do m0,v
        merge(m0, DAGModel(theModule, findStatement(m, v)))
    end
    return m
end

getReturn(am::AbstractModel) = Model(am).retn

function setReturn(m::DAGModel, x)
    theModule = getmodule(m)
    m0 = assemblefrom(m, parameters(m), arguments(m))
    isnothing(x) && return m0
    return merge(m0, DAGModel(theModule, Return(x)))
end 

function trim_args!(args, m, params)
    g = digraph(m)
    intersect!(args, setdiff(vcat((parents(g, p) for p in params)...), params))
end

sourcenodes(g::SimpleDigraph) = setdiff(vlist(g), [last(e) for e in elist(g)])
sinknodes(g::SimpleDigraph) = setdiff(vlist(g), [first(e) for e in elist(g)])

"""
    after(m::DAGModel, xs...; strict=false)

Transforms `m` by moving `xs` to arguments. If `strict=true`, only descendants of `xs` are retained in the body. Otherwise, the remaining variables in the body are unmodified. Unused arguments are trimmed.

`predictive(m::DAGModel, xs...) = after(m, xs..., strict = true)`

`Do(m::DAGModel, xs...) = after(m, xs..., strict = false)`

# Example
```jldoctest
julia> m = @model (n, k) begin
           β ~ Gamma()
           α ~ Gamma()
           θ ~ Beta(α, β)
           x ~ Binomial(n, θ)
           z ~ Binomial(k, α / (α + β))
       end;

julia> Soss.after(m, :θ, strict=false) # same as Do(m, :θ)
@model (n, k, θ) begin
        β ~ Gamma()
        α ~ Gamma()
        x ~ Binomial(n, θ)
        z ~ Binomial(k, α / (α + β))
    end


julia> Soss.after(m, :θ, strict = true) # same as predictive(m, :θ)
@model (n, θ) begin
        x ~ Binomial(n, θ)
    end
```
"""
function after(m::DAGModel, xs...; strict = false)
    g = digraph(m)
    for x in xs
        map(a->delete!(g, a, x), in_neighbors(g, x))
    end
    parms = Symbol[]
    for v in sinknodes(g)
        sinkparents = before(g, v)
        !strict || any(in(sinkparents).(xs)) ? append!(parms, sinkparents) : nothing
    end
    args = arguments(m) ∪ xs # Will trim later.
    parms = setdiff(parms, args)
    trim_args!(args, m, parms)
    m1 = setReturn(assemblefrom(m, parms, args), getReturn(m))
    newargs = arguments(m1) ∪ setdiff(variables(m) ∩ variables(getReturn(m1)), variables(m1))
    return merge(m1, Model(getmodule(m), newargs, quote end))
end

"""
    before(m::DAGModel, xs...; inclusive=true, strict=true)

Transforms `m` by retaining all ancestors of any of `xs` if `strict=true`; if `strict=false`, retains all variables that are not descendants of any `xs`. Note that adding more variables to `xs` cannot result in a larger model. If `inclusive=true`, `xs` is considered to be an ancestor of itself and is always included in the returned `DAGModel`. Unneeded arguments are trimmed.

`prune(m::DAGModel, xs...) = before(m, xs..., inclusive = false, strict = false)`

`prior(m::DAGModel, xs...) = before(m, xs..., inclusive = true, strict = true)`

# Examples
```jldoctest
julia> m = @model (n, k) begin
           β ~ Gamma()
           α ~ Gamma()
           θ ~ Beta(α, β)
           x ~ Binomial(n, θ)
           z ~ Binomial(k, α / (α + β))
       end;

julia> Soss.before(m, :θ, inclusive = true, strict = true)
@model begin
        β ~ Gamma()
        α ~ Gamma()
        θ ~ Beta(α, β)
    end

julia> Soss.before(m, :θ, inclusive = true, strict = false)
@model k begin
        β ~ Gamma()
        α ~ Gamma()
        θ ~ Beta(α, β)
        z ~ Binomial(k, α / (α + β))
    end

julia> Soss.before(m, :θ, inclusive = false, strict = true) # same as Soss.prior(m, :θ)
@model begin
        β ~ Gamma()
        α ~ Gamma()
    end

julia> Soss.before(m, :θ, inclusive=false, strict=false) # same as Soss.prune(m, :θ)
@model k begin
        β ~ Gamma()
        α ~ Gamma()
        z ~ Binomial(k, α / (α + β))
    end
```
"""
function before(m::DAGModel, xs...; inclusive = true, strict = true)
    g = digraph(m)
    vars = strict ? before(g, xs..., inclusive = inclusive) : notafter(g, xs..., inclusive = inclusive)
    args = arguments(m) ∩ vars
    params = setdiff(vars, args)
    trim_args!(args, m, params)
    return assemblefrom(m, params, args)
end
