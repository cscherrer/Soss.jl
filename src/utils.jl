using MLStyle
using DataStructures
using SimpleGraphs
using SimplePosets


export argtuple
argtuple(m) = arguments(m) |> astuple

astuple(x) = Expr(:tuple,x...)

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
stochastic(st :: Let)        = Symbol[]
stochastic(st :: Follows)    = Symbol[st.x]
stochastic(st :: Return)     = Symbol[]
stochastic(st :: LineNumber) = Symbol[]

stochastic(m :: Model) = union(stochastic.(m.body)...)

export bound
bound(st :: Let)        = Symbol[st.x]
bound(st :: Follows)    = Symbol[]
bound(st :: Return)     = Symbol[]
bound(st :: LineNumber) = Symbol[]

bound(m :: Model) = union(bound.(m.body)...)

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




export variables
variables(m :: Model) = arguments(m) ∪ stochastic(m) ∪ bound(m)

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
    g = SimpleDigraph{Symbol}()

    
    mvars = variables(m)
    for v in mvars
        add!(g, v)
    end

    f!(g, st::Let) = 
        for v in mvars ∩ variables(st.rhs)
            add!(g, v, st.x)
        end
    f!(g, st::Follows) = 
        for v in mvars ∩ variables(st.rhs)
            add!(g, v, st.x)
        end
    f!(g, st::Return)  = nothing
    f!(g, st::LineNumber) = nothing

    for st in m.body
        f!(g, st)
    end

    g
end

    
export poset
function poset(m::Model)
    po = SimplePoset{Symbol}()

    mvars = variables(m)
    for v in mvars
        add!(po, v)
    end

    f!(po, st::Let) = 
        for v in mvars ∩ variables(st.rhs)
            add!(po, v, st.x)
        end
    f!(po, st::Follows) = 
        for v in mvars ∩ variables(st.rhs)
            add!(po, v, st.x)
        end
    f!(po, st::Return)  = nothing
    f!(po, st::LineNumber) = nothing

    for st in m.body
        f!(po, st)
    end

    po
end


export dependencies
dependencies = poset


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

macro preval(x)
    eval(x) |> esc
end

macro logdensity(n)
    @show n
    :(@preval sourceLogdensity($n))
end



export sourceLogdensity
function sourceLogdensity(m::Model; ℓ=:ℓ)
    proc(m, st :: Follows)    = :($ℓ += logpdf($(st.rhs), $(st.x)))
    proc(m, st :: Let)        = :($(st.x) = $(st.rhs))
    proc(m, st :: Return)     = nothing
    proc(m, st :: LineNumber) = nothing
    proc(::Nothing)        = nothing
    body = buildSource(m, proc)

    unknowns = parameters(m) ∪ arguments(m)
    unkExpr = Expr(:tuple,unknowns...)
    @gensym logdensity
    # result = @q function $logdensity(pars)
    result = @q function(pars)
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

export prior
function prior(m :: Model)
    po = dependencies(m)
    keep = parameters(m)
    for v in keep
        union!(keep, below(po, v))
    end
    proc(m, st::Follows) = st.x ∈ keep
    proc(m, st::Let)     = st.x ∈ keep
    proc(m, st) = true
    newbody = filter(st -> proc(m,st), m.body)
    Model([],newbody)
end



# # export priorPredictive
# # function priorPredictive(m :: Model)
# #     args = copy(m.args)
# #     body = postwalk(m.body) do x
# #         if @capture(x, v_ ~ dist_)
# #             setdiff!(args, [v])
# #             x
# #         elseif @capture(x, v_ ⩪ dist_)
# #             setdiff!(args, [v])
# #             @q ($v ~ $dist)
# #         else x
# #         end
# #     end
# #     Model(args, body)
# # end

# export likelihood
# function likelihood(m :: Model)
#     m = annotate(m)
#     args = copy(m.args)
#     body = postwalk(m.body) do x
#         if @capture(x, v_ ~ dist_)
#             union!(args, [v])
#             Nothing
#         elseif @capture(x, v_ ⩪ dist_)
#             setdiff!(args, [v])
#             @q ($v ~ $dist)
#         else x
#         end
#     end
#     Model(args, body) |> pretty
# end


# export annotate
# function annotate(m::Model)
#     newbody = postwalk(m.body) do x
#         if @capture(x, v_ ~ dist_)
#             if v ∈ observed(m)
#                 @q $v ⩪ $dist
#             else
#                 x
#             end
#         else x
#         end
#     end

#     Model(args = m.args, body=newbody, meta = m.meta)
# end


# export pretty
# pretty = stripNothing ∘ striplines ∘ flatten

# export expandSubmodels
# function expandSubmodels(m :: Model)
#     newbody = postwalk(m.body) do x
#         if @capture(x, @model expr__)
#             eval(x)
#         else x
#         end
#     end
#     Model(args=m.args, body=newbody, meta=m.meta)
# end


export unobserve
function unobserve(m::Model)
    Model(freeVariables(m), m.body)
end


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