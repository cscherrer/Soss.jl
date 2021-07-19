using MLStyle
import SimplePosets
using NestedTuples
using NestedTuples: LazyMerge

expr(x) = :(identity($x))

# like `something`, but doesn't throw an error
maybesomething() = nothing
maybesomething(x::Nothing, y...) = maybesomething(y...)
maybesomething(x::Some, y...) = x.value
maybesomething(x::Any, y...) = x


export argtuple
argtuple(m) = arguments(m) |> astuple

astuple(x) = Expr(:tuple,x...)
astuple(x::Symbol) = Expr(:tuple,x)



export arguments
arguments(m::AbstractModelFunction) = Model(m).args

export sampled
sampled(m::AbstractModelFunction) = keys(Model(m).dists) |> collect

export assigned
assigned(m::AbstractModelFunction) = keys(Model(m).vals) |> collect

export parameters
function parameters(a::AbstractModelFunction)
    m = Model(a)
    union(assigned(Model(m)), sampled(m))
end

export variables
variables(m::DAGModel) = union(arguments(m), parameters(m))

function variables(expr :: Expr)
    leaf(x::Symbol) = begin
        [x]
    end
    leaf(x) = []
    branch(head, newargs) = begin
        union(newargs...)
    end
    foldall(leaf, branch)(expr)
end

variables(s::Symbol) = [s]
variables(x) = []

for f in [:arguments, :assigned, :sampled, :parameters, :variables]
    @eval function $f(m::DAGModel, nt::NamedTuple)
        vs = $f(m)
        isempty(vs) && return NamedTuple()
        return select(nt, $f(m))
    end
end


export foldall
function foldall(leaf, branch; kwargs...)
    function go(ast)
        MLStyle.@match ast begin
            Expr(head, args...) => branch(head, map(go, args); kwargs...)
            x                   => leaf(x; kwargs...)
        end
    end

    return go
end

export foldall1
function foldall1(leaf, branch; kwargs...)
    function go(ast)
        MLStyle.@match ast begin
            Expr(head, arg1, args...) => branch(head, arg1, map(go, args); kwargs...)
            x                         => leaf(x; kwargs...)
        end
    end

    return go
end



import MacroTools: striplines, @q




# function arguments(model::DAGModel)
#     model.args
# end




allequal(xs) = all(xs[1] .== xs)



# # fold example usage:
# # ------------------
# # function leafCount(ast)
# #     leaf(x) = 1
# #     expr(head, arg1, newargs) = sum(newargs)
# #     fold(leaf, expr)(ast)
# # end

# # leaves = begin
# #     leaf(x) = [x]
# #     expr(head, arg1, newargs) = union(newargs...)
# #     fold(leaf, expr)
# # end

# # ast = :(f(x + 3y))

# # leaves(ast)

# # Example of Tamas Papp's `as` combinator:
# # julia> as((;s=as(Array, as𝕀,4), a=asℝ))(randn(5))
# # (s = [0.545324, 0.281332, 0.418541, 0.485946], a = 2.217762640580984)

function buildSource(m, proc, wrap=identity; kwargs...)

    kernel = @q begin end

    for st in map(v -> findStatement(m,v), toposort(m))
        ex = proc(m, st; kwargs...)
        isnothing(ex) || push!(kernel.args, ex)
    end


    isnothing(m.retn) || push!(kernel.args, proc(m, Return(m.retn); kwargs...))
    # args = argtuple(m)

    # body = @q begin
    #     function $basename($args; kwargs...)
    #         $(wrap(kernel))
    #     end
    # end

    wrap(kernel) |> MacroTools.flatten
    # flatten(body)
end

# From https://github.com/thautwarm/MLStyle.jl/issues/66
@active LamExpr(x) begin
           @match x begin
               :($a -> begin $(bs...) end) =>
                 let exprs = filter(x -> !(x isa LineNumberNode), bs)
                   if length(exprs) == 1
                     (a, exprs[1])
                   else
                     (a, Expr(:block, bs...))
                     end
               end
                _  => nothing
           end
       end




# using BenchmarkTools
# f(;kwargs...) = kwargs[:a] + kwargs[:b]

# @btime invokefrozen(f, Int; a=3,b=4)  # 3.466 ns (0 allocations: 0 bytes)
# @btime f(;a=3,b=4)                    # 1.152 ns (0 allocations: 0 bytes)


# @isdefined
# Base.@locals
# @__MODULE__
# names

# getprototype(::Type{NamedTuple{(),Tuple{}}}) = NamedTuple()
getprototype(::Type{NamedTuple{N,T} where {T <: Tuple} } ) where {N} = NamedTuple{N}
getprototype(::NamedTuple{N,T} where {T<: Tuple} ) where N = NamedTuple{N}

function loadvals(argstype, datatype)
    args = getntkeys(argstype)
    data = getntkeys(datatype)
    loader = @q begin
    end

    for k in args
        push!(loader.args, :($k = _args.$k))
    end
    for k in data
        push!(loader.args, :($k = _data.$k))
    end

    src -> (@q begin
        $loader
        $src
    end) |> MacroTools.flatten
end

function loadvals(argstype, datatype, parstype)
    args = getntkeys(argstype)
    data = getntkeys(datatype)
    pars = getntkeys(parstype)

    loader = @q begin

    end

    for k in args
        push!(loader.args, :($k = _args.$k))
    end
    for k in setdiff(data, pars)
        push!(loader.args, :($k = _data.$k))
    end

    for k in setdiff(pars, data)
        push!(loader.args, :($k = _pars.$k))
    end

    for k in pars ∩ data
        push!(loader.args, :($k = Soss.NestedTuples.lazymerge(_data.$k, _pars.$k)))
    end

    src -> (@q begin
        $loader
        $src
    end) |> MacroTools.flatten
end


getntkeys(::NamedTuple{A,B}) where {A,B} = A
getntkeys(::Type{NamedTuple{A,B}}) where {A,B} = A
getntkeys(::Type{NamedTuple{A}}) where {A} = A
getntkeys(::Type{LazyMerge{A,B,S,T}}) where {A,B,S,T} = Tuple(A ∪ B)


# These macros quickly define additional methods for when you get tired of typing `NamedTuple()`
macro tuple3args(f)
    quote
        $f(m::DAGModel, (), data) = $f(m::DAGModel, NamedTuple(), data)
        $f(m::DAGModel, args, ()) = $f(m::DAGModel, args, NamedTuple())
        $f(m::DAGModel, (), ())   = $f(m::DAGModel, NamedTuple(), NamedTuple())
    end
end

macro tuple2args(f)
    quote
        $f(m::DAGModel, ()) = $f(m::DAGModel, NamedTuple())
    end
end


# This is just handy for REPLing, no direct connection to Soss

# julia> tower(Int)
# 6-element Array{DataType,1}:
#  Int64
#  Signed
#  Integer
#  Real
#  Number
#  Any

export tower

function tower(x)
    t0 = typeof(x)
    result = [t0]
    t1 = supertype(t0)
    while t1 ≠ t0
        push!(result, t1)
        t0, t1 = t1, supertype(t1)
    end
    return result
end

const TypeLevel = GeneralizedGenerated.TypeLevel


function isleaf(m, v::Symbol)
    isempty(digraph(m).N[v])
end

export unVal
export val2nt

unVal(::Type{V}) where {T, V <: Val{T}} = T
unVal(::Val{T}) where {T} = T

function val2nt(v,x)
    k = Soss.unVal(v)
    NamedTuple{(k,)}((x,))
end
