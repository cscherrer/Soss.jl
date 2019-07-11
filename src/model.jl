export Model, @model
using MLStyle

using SimpleGraphs
using SimplePosets

abstract type AbstractModel end

struct Model <: AbstractModel
    args :: Vector{Symbol}
    body :: Vector{Statement}
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
    args = m.args ∪ collect(vs)
    Model(args, m.body) |> condition(args...)
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
    partition = simplify(g) |> SimpleGraphs.components |> collect

    keep = []
    for v ∈ vs
        v_component = partition[in.(v, partition)][1]
        union!(keep, v_component)
    end

    function proc(m, st::Let)
        st.x ∈ keep && return st
        return nothing
    end 
    function proc(m, st::Follows)
        st.x ∈ vs && return Let(st.x, kwargs[st.x])
        st.x ∈ keep && return st
        return nothing
    end
    proc(m, st) = st

    newbody = buildSource(m, proc)
    Model(m.args,newbody)
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
    q = @q begin
        @model $(args) $(convert(Expr, m.body))
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
