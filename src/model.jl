export Model, @model
using MLStyle

using MacroTools: @q, striplines
using SimpleGraphs
using SimplePosets
using GG

abstract type AbstractModel{T} end
modeltype(::Type{<:AbstractModel{T}}) where {T} = T

struct Model{T} <: AbstractModel{T}
    args  :: Vector{Symbol}
    vals   :: NamedTuple
    dists  :: NamedTuple
    retn  :: Union{Nothing, Expr}
    data  :: NamedTuple
end

function Model(args, vals, dists, retn, data)
    m = Model{Any}(args, vals, dists, retn, data)
    T = convert(Expr, m) |> expr2typelevel
    Model{T}(args, vals, dists, retn, data)
end

const emptyModel = let T = :(@model begin end) |> expr2typelevel
    Model{T}([], NamedTuple(), NamedTuple(), nothing, NamedTuple())
end


function Base.merge(m1::Model, m2::Model) 
    vals = merge(m1.vals, m2.vals)
    args = setdiff(union(m1.args, m2.args), keys(vals))
    dists = merge(m1.dists, m2.dists)
    retn = maybesomething(m2.retn, m1.retn) # m2 first so it gets priority
    data = merge(m1.data, m2.data)

  
    Model(args, vals, dists, retn, data)
end

Base.merge(m::Model, ::Nothing) = m


function Model(expr :: Expr)
    @match expr begin
        :($k = $v)   => Model([], namedtuple(k)([v]), NamedTuple(), nothing, NamedTuple())
        :($k ~ $v)   => Model([], NamedTuple(), namedtuple(k)([v]), nothing, NamedTuple())
        :(return :v) => Model([], NamedTuple(), NamedTuple(), v, NamedTuple())
        Expr(:block, body...) => foldl(merge, Model.(body))
        :(@model $lnn begin $b end) => Model(b)
        # Expr(:macrocall, :(@model), lnn, args...) => Model(args...)
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


function Base.convert(::Type{Expr}, m::Model{T} where T)
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


function Base.get(m::Model, k::Symbol)
    result = []

    if k ∈ keys(m.val) 
        push!(result, Assign(k,getproperty(m.val, k)))
    elseif k ∈ keys(m.dist)
        if k ∈ keys(m.data)
            push!(result, Observe(k,getproperty(m.dist, k)))
        else
            push!(result, Sample(k,getproperty(m.dist, k)))
        end
    end
    return result
end

# For pretty-printing in the REPL
Base.show(io::IO, m :: Model) = println(io, convert(Expr, m))