struct DAGModel{A,B,M<:GeneralizedGenerated.TypeLevel} <: AbstractModel{A,B,M,Nothing,Nothing}
    args  :: Vector{Symbol}
    vals  :: NamedTuple
    dists :: NamedTuple
    retn  :: Union{Nothing, Symbol, Expr}
end




function DAGModel(theModule::Module, args, vals, dists, retn)
    M = to_type(theModule)
    A = NamedTuple{Tuple(args)}
    m = DAGModel{A,Any,M}(args, vals, dists, retn)
    B = convert(Expr, m).args[end] |> to_type
    DAGModel{A,B,M}(args, vals, dists, retn)
end

function type2model(::Type{DAGModel{A,B,M}}) where {A,B,M}
    args = [fieldnames(A)...]
    body = from_type(B)
    DAGModel(from_type(M), convert(Vector{Symbol},args), body)
end

function emptyDAGModel(theModule::Module)
    M = to_type(theModule)
    A = NamedTuple{(),Tuple{}}
    B = (@q begin end) |> to_type
    DAGModel{A,B,M}([], NamedTuple(), NamedTuple(), nothing)
end


function Base.merge(m1::DAGModel, m2::DAGModel)
    theModule = getmodule(m1)
    @assert theModule == getmodule(m2)
    vals = merge(m1.vals, m2.vals)
    args = setdiff(union(m1.args, m2.args), keys(vals))
    dists = merge(m1.dists, m2.dists)
    retn = maybesomething(m2.retn, m1.retn) # m2 first so it gets priority

    DAGModel(theModule, args, vals, dists, retn)
end

Base.merge(m::DAGModel, ::Nothing) = m

DAGModel(theModule::Module, arg::Arg) = DAGModel(theModule, Symbol[arg.x], NamedTuple(), NamedTuple(), nothing)
DAGModel(theModule::Module, st::Assign) = DAGModel(theModule, Symbol[], namedtuple(st.x)([st.rhs]), NamedTuple(), nothing)
DAGModel(theModule::Module, st::Sample) = DAGModel(theModule, Symbol[], NamedTuple(), namedtuple(st.x)([st.rhs]), nothing)
DAGModel(theModule::Module, st::Return) = DAGModel(theModule, Symbol[], NamedTuple(), NamedTuple(), st.rhs)
DAGModel(theModule::Module, st::LineNumber) = emptyDAGModel(theModule)

DAGModel(theModule::Module, ::LineNumberNode) = emptyDAGModel(theModule)

function DAGModel(theModule::Module, expr :: Expr)
    nt = NamedTuple()
    @match expr begin
        :($k = $v)   => DAGModel(theModule, Assign(k,v))
        :($k ~ $v)   => DAGModel(theModule, Sample(k,v))
        :($k .~ $v)  => DAGModel(theModule, Sample(k, :(For(identity, $v))))
        Expr(:return, x...) => DAGModel(theModule, Return(x[1]))
        Expr(:block, body...) => foldl(merge, map(body) do line DAGModel(theModule, line) end)
        :(@model $lnn $body) => DAGModel(theModule, body)
        :(@model $lnn $args $body) => DAGModel(theModule, args.args, body)

        x => begin
            @error "Bad argument to DAGModel(::Expr)" expr=x
        end
    end
end

function DAGModel(vs::Expr,expr::Expr)
    @assert vs.head == :tuple
    @assert expr.head == :block
    DAGModel(Vector{Symbol}(vs.args), expr)
end

function DAGModel{A,B,M}(args::Vector{Symbol}, expr::Expr) where {A,B,M}
    m1 = DAGModel{A,B,M}(args, NamedTuple(), NamedTuple(), nothing)
    m2 = DAGModel{A,B,M}(expr)
    merge(m1, m2)
end

function DAGModel(theModule::Module, args::Vector{Symbol}, expr::Expr)
    m1 = DAGModel(theModule, args, NamedTuple(), NamedTuple(), nothing)
    m2 = DAGModel(theModule, expr)
    merge(m1, m2)
end

DAGModel(m::DAGModel) = m

Expr(m::DAGModel,v) = convert(Expr,findStatement(m,v) )

DAGModel(::LineNumberNode) = emptyDAGModel

toargs(vs :: Vector{Symbol}) = Tuple(vs)
toargs(vs :: NTuple{N,Symbol} where {N}) = vs



macro model(vs::Expr,expr::Expr)
    theModule = __module__
    @assert vs.head == :tuple
    @assert expr.head == :block
    ASTModel(theModule,Vector{Symbol}(vs.args), expr)
end

macro model(v::Symbol, expr::Expr)
    theModule = __module__
    ASTModel(theModule,[v], expr)
end

macro model(expr :: Expr)
    theModule = __module__
    ASTModel(theModule,Vector{Symbol}(), expr)
end




function Base.convert(::Type{Expr}, m::DAGModel{T} where T)
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


# function Base.get(m::DAGModel, k::Symbol)
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
Base.show(io::IO, m :: DAGModel) = println(io, convert(Expr, m))

# export observe
# observe(m,v::Symbol) = merge(m, DAGModel(Symbol[], NamedTuple(), NamedTuple(), nothing, Symbol[v]))
# observe(m,vs::Vector{Symbol}) = merge(m, DAGModel(Symbol[], NamedTuple(), NamedTuple(), nothing, vs))

function findStatement(am::AbstractModel, x::Symbol)
    m = Model(am)
    x == :return && return Return(m.retn)
    x ∈ keys(m.vals) && return Assign(x,m.vals[x])
    x ∈ keys(m.dists) && return Sample(x,m.dists[x])
    x ∈ arguments(m) && return Arg(x)
    error("statement not found")
end


function statements(am::AbstractModel)
    m = Model(am)
    s = Statement[Soss.findStatement(m, v) for v in variables(m)]
    return s
end
