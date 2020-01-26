export Model, @model
using MLStyle

using MacroTools: @q, striplines
using SimpleGraphs
using SimplePosets
using GeneralizedGenerated

struct Model{A,B,M} 
    args  :: Vector{Symbol}
    vals  :: NamedTuple
    dists :: NamedTuple
    retn  :: Union{Nothing, Symbol, Expr}
end

argstype(::Model{A,B,M}) where {A,B,M} = A
bodytype(::Model{A,B,M}) where {A,B,M} = B

argstype(::Type{Model{A,B,M}}) where {A,B,M} = A
bodytype(::Type{Model{A,B,M}}) where {A,B,M} = B

getmodule(::Type{Model{A,B,M}}) where {A,B,M} = from_type(M)
getmodule(::Model{A,B,M}) where {A,B,M} = from_type(M)

getmoduletypencoding(::Type{Model{A,B,M}}) where {A, B, M} = M
getmoduletypencoding(::Model{A,B,M}) where {A,B,M} = M

function Model(theModule::Module, args, vals, dists, retn)
    M = to_type(theModule)
    A = NamedTuple{Tuple(args)}
    m = Model{A,Any,M}(args, vals, dists, retn)
    B = convert(Expr, m).args[end] |> to_type
    Model{A,B,M}(args, vals, dists, retn)
end

function type2model(::Type{Model{A,B,M}}) where {A,B,M}
    args = [fieldnames(A)...]
    body = from_type(B)
    Model(from_type(M), convert(Vector{Symbol},args), body)
end

function emptyModel(theModule::Module)
    M = to_type(theModule)
    A = NamedTuple{(),Tuple{}}                    
    B = (@q begin end) |> to_type
    Model{A,B,M}([], NamedTuple(), NamedTuple(), nothing)
end


function Base.merge(m1::Model, m2::Model) 
    theModule = getmodule(m1)
    @assert theModule == getmodule(m2)
    vals = merge(m1.vals, m2.vals)
    args = setdiff(union(m1.args, m2.args), keys(vals))
    dists = merge(m1.dists, m2.dists)
    retn = maybesomething(m2.retn, m1.retn) # m2 first so it gets priority
  
    Model(theModule, args, vals, dists, retn)
end

Base.merge(m::Model, ::Nothing) = m

Model(theModule::Module, st::Assign) = Model(theModule, Symbol[], namedtuple(st.x)([st.rhs]), NamedTuple(), nothing)
Model(theModule::Module, st::Sample) = Model(theModule, Symbol[], NamedTuple(), namedtuple(st.x)([st.rhs]), nothing)
Model(theModule::Module, st::Return) = Model(theModule, Symbol[], NamedTuple(), NamedTuple(), st.rhs)
Model(theModule::Module, st::LineNumber) = emptyModel(theModule)

Model(theModule::Module, ::LineNumberNode) = emptyModel(theModule)

function Model(theModule::Module, expr :: Expr)
    nt = NamedTuple()
    @match expr begin
        :($k = $v)   => Model(theModule, Assign(k,v))
        :($k ~ $v)   => Model(theModule, Sample(k,v))
        Expr(:return, x...) => Model(theModule, Return(x[1]))
        Expr(:block, body...) => foldl(merge, map(body) do line Model(theModule, line) end)
        :(@model $lnn $body) => Model(theModule, body)
        :(@model $lnn $args $body) => Model(theModule, args.args, body)

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

function Model{A,B,M}(args::Vector{Symbol}, expr::Expr) where {A,B,M}
    m1 = Model{A,B,M}(args, NamedTuple(), NamedTuple(), nothing)
    m2 = Model{A,B,M}(expr)
    merge(m1, m2)
end

function Model(theModule::Module, args::Vector{Symbol}, expr::Expr)
    m1 = Model(theModule, args, NamedTuple(), NamedTuple(), nothing)
    m2 = Model(theModule, expr)
    merge(m1, m2)
end


Expr(m::Model,v) = convert(Expr,findStatement(m,v) )

Model(::LineNumberNode) = emptyModel

toargs(vs :: Vector{Symbol}) = Tuple(vs)
toargs(vs :: NTuple{N,Symbol} where {N}) = vs



macro model(vs::Expr,expr::Expr)
    theModule = __module__
    @assert vs.head == :tuple
    @assert expr.head == :block
    Model(theModule,Vector{Symbol}(vs.args), expr)
end

macro model(v::Symbol, expr::Expr)
    theModule = __module__
    Model(theModule,[v], expr)
end

macro model(expr :: Expr)
    theModule = __module__
    Model(theModule,Vector{Symbol}(), expr) 
end




function Base.convert(::Type{Expr}, m::Model{T} where T)
    numArgs = length(m.args)
    args = if numArgs == 1
       m.args[1]
    elseif numArgs > 1
        Expr(:tuple, [x for x in m.args]...)
    end

    body = @q begin end

    for v ∈ setdiff(toposort(m), arguments(m))
        push!(body.args, Expr(m,v))
    end

    isnothing(m.retn) || push!(body.args, :(return $(m.retn)))

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


# function Base.get(m::Model, k::Symbol)
#     result = []

#     if k ∈ keys(m.vals) 
#         push!(result, Assign(k,getproperty(m.vals, k)))
#     elseif k ∈ keys(m.dists)
#         if k ∈ keys(m.data)
#             push!(result, Observe(k,getproperty(m.dists, k)))
#         else
#             push!(result, Sample(k,getproperty(m.dists, k)))
#         end
#     end
#     return result
# end

# For pretty-printing in the REPL
Base.show(io::IO, m :: Model) = println(io, convert(Expr, m))

# (m::Model)(;kwargs...) = merge(m, Model(Symbol[], NamedTuple(), NamedTuple(), nothing,  ;kwargs...)))
# export observe
# observe(m,v::Symbol) = merge(m, Model(Symbol[], NamedTuple(), NamedTuple(), nothing, Symbol[v]))
# observe(m,vs::Vector{Symbol}) = merge(m, Model(Symbol[], NamedTuple(), NamedTuple(), nothing, vs))

function findStatement(m::Model, x::Symbol)
    x ∈ keys(m.vals) && return Assign(x,m.vals[x])
    x ∈ keys(m.dists) && return Sample(x,m.dists[x])
    x ∈ arguments(m) && return Arg(x)
    error("statement not found")
end