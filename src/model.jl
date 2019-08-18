export Model, @model
using MLStyle

using SimpleGraphs
using SimplePosets

abstract type AbstractModel end

Context{T} = NamedTuple{S, NTuple{N,T}} where {S,N}

struct Model <: AbstractModel
    args  :: Vector{Symbol}
    val   :: NamedTuple
    dist  :: Context{Union{Symbol, Expr}} 
    retn  :: Union{Nothing, Expr}
    data  :: NamedTuple
end

const emptyModel = Model([], NamedTuple(), NamedTuple(), nothing, NamedTuple())

function Base.merge(m1::Model, m2::Model) 
    val = merge(m1.val, m2.val)
    args = setdiff(union(m1.args, m2.args), keys(val))
    dist = merge(m1.dist, m2.dist)
    retn = something(m2.retn, m1.retn) # m2 first so it gets priority
    data = merge(m1.data, m2.data)
end

function Model(expr :: Expr)
    @match expr begin
        :($k = $v)   => Model([], namedtuple(k)(v), NamedTuple(), nothing, NamedTuple())
        :($k ~ $v)   => Model([], NamedTuple(), namedtuple(k)(v), nothing, NamedTuple())
        :(return :v) => Model([], NamedTuple(), NamedTuple(), v, NamedTuple())
        :(begin $body end) => foldl(merge, Model.(body))
        
        x            => @error "Bad argument to Model(::Expr)"
    end
end

function Model(vs :: Vector{Symbol}, expr :: Expr)
    body = [Statement(x) for x in expr.args]
    Model(vs, body)
end

macro model(vs::Expr,expr::Expr)
    @assert vs.head == :tuple
    @assert expr.head == :block
    Model(Vector{Symbol}(vs.args), expr)
end

macro model(v::Symbol, expr::Expr)
    Model([v], expr)
end

macro model(expr :: Expr)
    Model(Vector{Symbol}(), expr) 
end

(m::Model)(vs...) = begin
    vs = collect(vs)
    vars = variables(m)
    args = m.args ∪ vs

    po = poset(m)
    g = digraph(m)
    
    function proc(m, st::Let)
        st.x ∈ vs && return nothing
        return st
    end
    function proc(m, st::Follows)
        if st.x ∈ vs && isempty(vars ∩ variables(st.rhs))
            return nothing
        end
        return st
    end
    proc(m, st) = st
    newbody = buildSource(m, proc)
    Model(args,newbody) |> toposort
end


(m::Model)(;kwargs...) = begin
    po = poset(m)
    g = digraph(m)

    vs = keys(kwargs)
    # Make v ∈ vs no longer depend on other variables
    for v ∈ vs
        for x in below(po, v)
            delete!(g, x, v)
        end
    end

    # Find connected components of what's left after removing parents
    partition = SimpleGraphs.simplify(g) |> SimpleGraphs.components |> collect

    keep = Symbol[]
    for v ∈ vs
        v_component = partition[in.(v, partition)][1]
        union!(keep, v_component)
    end

    function proc(m, st::Let)
        st.x ∈ vs && return nothing
        st.x ∈ keep && return st
        return nothing
    end
    function proc(m, st::Follows)
        st.x ∈ vs && return nothing
        st.x ∈ keep && return st
        return nothing
    end
    proc(m, st) = st
    newargs = keep ∩ setdiff(m.args, vs) 
    newbody = buildSource(m, proc)
    for k in keys(kwargs)
        push!(newbody.args, Let(k, kwargs[k]))
    end
    Model(newargs,newbody) |> toposort
end

function Base.show(io::IO, m::Model) 
    print(io, convert(Expr, m))
end



function Base.convert(::Type{Expr}, m::Model)
    numArgs = length(m.args)
    args = if numArgs == 1
       m.args[1]
    elseif numArgs > 1
        Expr(:tuple, [x for x in m.args]...)
    end
    q = if numArgs == 0
        @q begin
            @model $(convert(Expr, m.body))
        end
    else
        @q begin
            @model $(args) $(convert(Expr, m.body))
        end
    end
    striplines(q).args[1]
end

dropLines(l::Let)        = [l]
dropLines(l::Follows)    = [l]
dropLines(l::Return)     = [l]
dropLines(l::LineNumber) = []

export dropLines
dropLines(m::Model) = begin
    newbody = cat(dropLines.(m.body)..., dims=1)
    Model(m.args, newbody)
end
