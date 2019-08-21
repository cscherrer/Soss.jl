export Model, @model
using MLStyle

using MacroTools: @q, striplines
using SimpleGraphs
using SimplePosets

abstract type AbstractModel end

Context{T} = NamedTuple{S, NTuple{N,T}} where {S,N}

struct Model <: AbstractModel
    args  :: Vector{Symbol}
    val   :: NamedTuple
    dist  :: NamedTuple
    retn  :: Union{Nothing, Expr}
    data  :: NamedTuple
end

const emptyModel = Model([], NamedTuple(), NamedTuple(), nothing, NamedTuple())


function Base.merge(m1::Model, m2::Model) 
    val = merge(m1.val, m2.val)
    args = setdiff(union(m1.args, m2.args), keys(val))
    dist = merge(m1.dist, m2.dist)
    retn = maybesomething(m2.retn, m1.retn) # m2 first so it gets priority
    data = merge(m1.data, m2.data)

    Model(args, val, dist, retn, data)
end

Base.merge(m::Model, ::Nothing) = m


function Model(expr :: Expr)
    @match expr begin
        :($k = $v)   => Model([], namedtuple(k)([v]), NamedTuple(), nothing, NamedTuple())
        :($k ~ $v)   => Model([], NamedTuple(), namedtuple(k)([v]), nothing, NamedTuple())
        :(return :v) => Model([], NamedTuple(), NamedTuple(), v, NamedTuple())
        Expr(:block, body...) => foldl(merge, Model.(body))
        x => begin
            @show x
            @error "Bad argument to Model(::Expr)"
        end
    end
end

function Model(args::Vector{Symbol}, expr::Expr)
    m1 = Model(args, NamedTuple(), NamedTuple(), nothing, NamedTuple())
    m2 = Model(expr)
    merge(m1, m2)
end

Model(::LineNumberNode) = emptyModel

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


(m::Model)(;kwargs...) = merge(m, Model([], NamedTuple(), NamedTuple(), nothing, (;kwargs...)))


function Base.convert(::Type{Expr}, m::Model)
    numArgs = length(m.args)
    args = if numArgs == 1
       m.args[1]
    elseif numArgs > 1
        Expr(:tuple, [x for x in m.args]...)
    end

    body = @q begin end

    for v ∈ setdiff(toposortvars(m), arguments(m))
        push!(body.args, Expr(m,v))
    end


    q = if numArgs == 0
        @q begin
            @model $body
        end
    else
        @q begin
            @model $(args) $body
        end
    end


    striplines(q).args[1]
end

# For pretty-printing in the REPL
Base.show(io::IO, m :: Model) = println(io, convert(Expr, m))