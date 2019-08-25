using MLStyle
using DataStructures
using SimpleGraphs
using SimplePosets

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

export variables
variables(m::Model) = m.args ∪ keys(m.vals) ∪ keys(m.dists)

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


export arguments
arguments(m) = m.args

export stochastic
stochastic(m::Model) = keys(m.dists)

export bound
bound(m::Model) = keys(m.vals)

# """
#     parameters(m::Model)

# A _parameter_ is a stochastic node that is only assigned once
# """
export observed
observed(m::Model) = keys(m.data)

export parameters
parameters(m::Model) = setdiff(
    stochastic(m), 
    observed(m)
)

export freeVariables
function freeVariables(m::Model)
    setdiff(arguments(m), stochastic(m))
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

# import LogDensityProblems: logdensity
# using ResumableFunctions

# export arguments, args, stochastic, observed, parameters, supports
# export paramSupport


# import MacroTools: striplines, flatten, unresolve, resyntax, @q, @capture
# using StatsFuns
using DataStructures: counter

# function arguments(model::Model)
#     model.args
# end




allequal(xs) = all(xs[1] .== xs)

# export findsubexprs
# function findsubexprs(expr, vs)
#     intersect(getSymbols(expr), vs)
# end


# export prior
# function prior(m :: Model)
#     po = dependencies(m)
#     keep = parameters(m)
#     for v in keep
#         union!(keep, below(po, v))
#     end
#     proc(m, st::Follows) = st.x ∈ keep
#     proc(m, st::Let)     = st.x ∈ keep
#     proc(m, st) = true
#     newbody = filter(st -> proc(m,st), m.body)
#     Model([],newbody)
# end


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

function buildSource(m, basename, proc, wrap=identity; kwargs...)

    kernel = @q begin end

    for st in map(v -> Statement(m,v), toposortvars(m))
        ex = proc(m, st; kwargs...)
        isnothing(ex) || push!(kernel.args, ex)
    end

    args = argtuple(m)

    body = @q begin
        function $basename($args; kwargs...)
            $(wrap(kernel))
        end
    end

    flatten(body)
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