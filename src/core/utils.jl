using MLStyle
# import SimplePosets
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
arguments(m::AbstractModel) = model(m).args

export sampled
sampled(m::AbstractModel) = keys(model(m).dists) |> collect

export assigned
assigned(m::AbstractModel) = keys(model(m).vals) |> collect

export parameters
function parameters(a::AbstractModel)
    m = model(a)
    union(assigned(model(m)), sampled(m)) 
end

export variables
# variables(m::DAGModel) = union(arguments(m), parameters(m))

function variables(expr :: Expr)
    leaf(s::Symbol) = begin
        [s]
    end
    leaf(x) = []
    branch(head, newargs) = begin
        union(newargs...)
    end
    foldall(leaf, branch)(expr)
end

variables(s::Symbol) = [s]
variables(x) = []

# for f in [:arguments, :assigned, :sampled, :parameters, :variables]
#     @eval function $f(m::DAGModel, nt::NamedTuple)
#         vs = $f(m)
#         isempty(vs) && return NamedTuple()
#         return select(nt, $f(m))
#     end
# end


export foldast
function foldast(leaf, branch)
    @inline function go(ast)
        MLStyle.@match ast begin
            Expr(head, args...) => branch(go, head, args)
            x                   => leaf(x)
        end
    end

    return go
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
    args = schema(argstype)
    data = schema(datatype)
    pars = schema(parstype)

    loader = @q begin

    end

    for k in keys(args)
        T = getproperty(args, k)
        push!(loader.args, :($k::$T = _args.$k))
    end
    for k in setdiff(keys(data), keys(pars))
        T = getproperty(data, k)
        push!(loader.args, :($k::$T = _data.$k))
    end

    for k in setdiff(keys(pars), keys(data))
        T = getproperty(pars, k)
        push!(loader.args, :($k::$T = _pars.$k))
    end

    for k in keys(pars) ∩ keys(data)
        qk = QuoteNode(k)
        if typejoin(getproperty(pars, k), getproperty(data, k)) <: NamedTuple
            push!(loader.args, :($k = Soss.NestedTuples.lazymerge(_data.$k, _pars.$k)))
        else
            T = getproperty(pars, k)
            push!(loader.args, quote
                _k = $qk
                @warn "Duplicate key, ignoring $_k in data"
                $k::$T = _pars.$k
            end)
        end
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

function detilde(ast)
    q = MLStyle.@match ast begin
            :($x ~ $rhs)        => :($x = _RAND($rhs))
            Expr(head, args...) => Expr(head, map(detilde, args)...)
            x                   => x
    end 

    MacroTools.flatten(q)
end

retilde(s::Symbol) = s
retilde(s::Number) = s

function retilde(v::JuliaVariables.Var)
    ifelse(v.name == :_RAND, :_RAND, v)
end

function retilde(ast)
    MLStyle.@match ast begin
            :($x = $v($rhs))        => begin
                    rx = retilde(x)
                    rv = retilde(v)
                    rrhs = retilde(rhs) 
                    if rv == :_RAND
                        return :($rx ~ $rrhs)
                    else
                        return :($rx = $rv($rrhs))
                    end
            end
            Expr(head, args...) => Expr(head, map(retilde, args)...)
            x                   => x
    end
end

asfun(m::AbstractModel) = :(($(arguments(m)...),) -> $(Soss.body(m)) ) 

function solve_scope(m::AbstractModel)   
    solve_scope(asfun(m))
end

function solve_scope(ex::Expr)
    ex |> detilde |> simplify_ex  |> MacroTools.flatten  |> solve_from_local |> retilde
end

function locally_bound(ex, optic)
    isolated = solve_scope(optic(ex))
    in_context = optic(solve_scope(ex))

    setdiff(globals(isolated), globals(in_context))
end    

"""
Given a JuliaVariables "solved" expression, convert back to a standard expression
"""
function unsolve(ex)
    ex = unwrap_scoped(ex)
    @match ex begin
        v::JuliaVariables.Var => v.name
        Expr(head, args...) => Expr(head, map(unsolve, args)...)
        x => x
    end
end


"""
Return the set of local variable names from a *solved* expression (using JuliaVariables)
"""
function locals(ex)
    go(ex) = @match ex begin
        v::JuliaVariables.Var => ifelse(v.is_global, Set{Symbol}(), Set((v.name,)))
        Expr(head, args...) => union(map(go, args)...)
        x => Set{Symbol}()
    end

    Tuple(go(ex))
end


# make_closure(funexpr)

# @gg function make_closure(__vars::NamedTuple{N,T}, funexpr) where {N,T}
#     funexpr = 
#     fdict = MacroTools.splitdef(funexpr)
#     for v in N
#         qv = QuoteNode(v)
#         pushfirst!(fdict[:body], :($v = getproperty(__vars, $qv)))
#     end

    
#     fdict[:args] = Any[:__ctx, Expr(:tuple, fdict[:args]...)]  


# f(ctx) = Base.Fix1(ctx) do ctx, j
#     p = ctx.p
#     Bernoulli(p/j)
# end

struct ReturnNow{T}
    value::T
end
