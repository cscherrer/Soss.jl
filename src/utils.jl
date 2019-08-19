using MLStyle
using DataStructures
using SimpleGraphs
using SimplePosets

# like `something`, but doesn't throw an error
maybesomething() = nothing
maybesomething(x::Nothing, y...) = maybesomething(y...)
maybesomething(x::Some, y...) = x.value
maybesomething(x::Any, y...) = x


export argtuple
argtuple(m) = arguments(m) |> astuple

astuple(x) = Expr(:tuple,x...)

export variables
variables(m::Model) = m.args ∪ keys(m.val) ∪ keys(m.dist)

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
stochastic(m::Model) = keys(m.dist)

export bound
bound(m::Model) = keys(m.val)

# """
#     parameters(m::Model)

# A _parameter_ is a stochastic node that is only assigned once
# """
export parameters
parameters(m::Model) = setdiff(
    stochastic(m), 
    arguments(m) ∪ bound(m)
)

export observed
observed(m::Model) = setdiff(stochastic(m), parameters(m))





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



# function condition(vs...) 
#     function cond(m)
#         po = dependencies(m)

#         maybeRemove = Symbol[]
#         # Bound v ∈ vs no longer depend on other variables
#         for v ∈ (vs ∩ bound(m))
#             for x in below(po, v)
#                 delete!(po, x, v)
#                 push!(maybeRemove, x)
#             end
#         end

#         # Go upward in the poset from the stuff we're keeping
#         # Keep everything maximal from there, and below
#         keep = [vs...]
#         for m in maximals(po)
#             xs = union([m],below(po,m))
#             if !isempty(keep ∩ xs)
#                 union!(keep, xs)
#             end
#         end

#         removable = setdiff(maybeRemove, keep)

#         function proc(st::Let)
#             st.x ∈ vs && return false
#             st.x ∈ removable && return false
#             return true
#         end
#         function proc(st::Follows) 
#             st.x ∈ removable && return false
#             return true
#         end
#         proc(st) = true

#         Model(m.args, filter(proc, m.body))
#     end

# end

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




export digraph
function digraph(m::Model)
    po = SimpleDigraph{Symbol}()

    mvars = variables(m)
    for v in mvars
        add!(po, v)
    end

    for (v, expr) in pairs(m.val)
        for p in variables(expr) ∩ variables(m)
            add!(po, p, v)
        end
    end

    for (v, expr) in pairs(m.dist)
        for p in variables(expr) ∩ variables(m)
            add!(po, p, v)
        end
    end

    po
end


    
export poset
function poset(m::Model)
    po = SimplePoset{Symbol}()

    mvars = variables(m)
    for v in mvars
        add!(po, v)
    end

    for (v, expr) in pairs(m.val)
        for p in variables(expr) ∩ variables(m)
            add!(po, p, v)
        end
    end

    for (v, expr) in pairs(m.dist)
        for p in variables(expr) ∩ variables(m)
            add!(po, p, v)
        end
    end

    po
end


# export dependencies
# dependencies = poset


# # export paramSupport
# # function paramSupport(model)
# #     supps = Dict{Symbol, Any}()
# #     postwalk(model.body) do x
# #         if @capture(x, v_ ~ dist_(args__))
# #             if v in parameters(model)
# #                 supps[v] = support(eval(dist))
# #             end
# #         else x
# #         end
# #     end
# #     return supps
# # end


export makeLogdensity
function makeLogdensity(m :: Model)
    fpre = sourceLogdensity(m) |> eval
    f(par) = invokefrozen(fpre, Real, par)
end


export logdensity
logdensity(m::Model, par) = makeLogdensity(m)(par)



export sourceLogdensity
function sourceLogdensity(m::Model; ℓ=:ℓ, fname = gensym(:logdensity))
    proc(m, st :: Observe)    = :($ℓ += logpdf($(st.rhs), $(st.x)))
    proc(m, st :: Assign)        = :($(st.x) = $(st.rhs))
    proc(m, st :: LineNumber) = nothing
    proc(::Nothing)        = nothing
    body = buildSource(m, proc)

    unknowns = parameters(m) ∪ arguments(m)
    unkExpr = Expr(:tuple,unknowns...)
    @gensym logdensity
    result = @q function $fname(pars)
        @unpack $(unkExpr) = pars
        $ℓ = 0.0

        $body
        return $ℓ
    end

    flatten(result)
end





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

function buildSource(m, proc; kwargs...)
    q = @q begin end
    for st in m.body
        ex = proc(m, st; kwargs...)
        isnothing(ex) || push!(q.args, ex)
    end
    q
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
