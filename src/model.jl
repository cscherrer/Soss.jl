export Model, @model
using MLStyle

using MacroTools: @q, striplines
using SimpleGraphs
using SimplePosets
using GG

struct Model{A,B,D} 
    args  :: Vector{Symbol}
    vals  :: NamedTuple
    dists :: NamedTuple
    retn  :: Union{Nothing, Expr}
    data  :: Vector{Symbol}
end

argstype(::Model{A,B,D}) where {A,B,D} = A
bodytype(::Model{A,B,D}) where {A,B,D} = B
datatype(::Model{A,B,D}) where {A,B,D} = D

argstype(::Type{Model{A,B,D}}) where {A,B,D} = A
bodytype(::Type{Model{A,B,D}}) where {A,B,D} = B
datatype(::Type{Model{A,B,D}}) where {A,B,D} = D



function Model(args, vals, dists, retn, data)
    A = NamedTuple{Tuple(args)}
    D = NamedTuple{Tuple(data)}
    m = Model{A,Any,D}(args, vals, dists, retn, data)
    B = convert(Expr, m).args[end] |> expr2typelevel
    Model{A,B,D}(args, vals, dists, retn, data)
end

function type2model(M::Type{Model{A,B,D}}) where {A,B,D}
    args = [fieldnames(A)...]
    data = [fieldnames(D)...]
    body = interpret(B)
    Model(convert(Vector{Symbol},args), body)
end

const emptyModel = 
    let A = NamedTuple{(),Tuple{}}
        D = NamedTuple{(),Tuple{}}                    
        B = (@q begin end) |> expr2typelevel
    Model{A,B,D}([], NamedTuple(), NamedTuple(), nothing, Symbol[])
end


function Base.merge(m1::Model, m2::Model) 
    vals = merge(m1.vals, m2.vals)
    args = setdiff(union(m1.args, m2.args), keys(vals))
    dists = merge(m1.dists, m2.dists)
    retn = maybesomething(m2.retn, m1.retn) # m2 first so it gets priority
    data = union(m1.data, m2.data)
  
    Model(args, vals, dists, retn, data)
end

Base.merge(m::Model, ::Nothing) = m


function Model(expr :: Expr)
    nt = NamedTuple()
    @match expr begin
        :($k = $v)   => Model(Symbol[], namedtuple(k)([v]), nt, nothing, Symbol[])
        :($k ~ $v)   => Model(Symbol[], nt, namedtuple(k)([v]), nothing, Symbol[])
        :($k ⩪ $v)   => Model(Symbol[], nt, namedtuple(k)([v]), nothing, Symbol[k])
        :(return :v) => Model(Symbol[], nt, nt, v, Symbol[])
        Expr(:block, body...) => foldl(merge, Model.(body))
        :(@model $lnn $body) => Model(body)
        :(@model $lnn $args $body) => Model(args.args, body)

        x => begin
            @error "Bad argument to Model(::Expr)" expr=x
        end
    end
end

function Model(vs::Expr,expr::Expr)
    @assert vs.head == :tuple
    @assert expr.head == :block
    Model(Vector{Symbol}(vs.args), expr)
end

function Model{A,B,D}(args::Vector{Symbol}, expr::Expr) where {A,B,D}
    m1 = Model{A,B,D}(args, NamedTuple(), NamedTuple(), nothing, Symbol[])
    m2 = Model{A,B,D}(expr)
    merge(m1, m2)
end

function Model(args::Vector{Symbol}, expr::Expr)
    m1 = Model(args, NamedTuple(), NamedTuple(), nothing, Symbol[])
    m2 = Model(expr)
    merge(m1, m2)
end

Model(::LineNumberNode) = emptyModel

toargs(vs :: Vector{Symbol}) = Tuple(vs)
toargs(vs :: NTuple{N,Symbol} where {N}) = vs



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

    if k ∈ keys(m.vals) 
        push!(result, Assign(k,getproperty(m.vals, k)))
    elseif k ∈ keys(m.dists)
        if k ∈ keys(m.data)
            push!(result, Observe(k,getproperty(m.dists, k)))
        else
            push!(result, Sample(k,getproperty(m.dists, k)))
        end
    end
    return result
end

# For pretty-printing in the REPL
Base.show(io::IO, m :: Model) = println(io, convert(Expr, m))

# (m::Model)(;kwargs...) = merge(m, Model(Symbol[], NamedTuple(), NamedTuple(), nothing,  ;kwargs...)))
export observe
observe(m,v::Symbol) = merge(m, Model(Symbol[], NamedTuple(), NamedTuple(), nothing, Symbol[v]))
observe(m,vs::Vector{Symbol}) = merge(m, Model(Symbol[], NamedTuple(), NamedTuple(), nothing, vs))