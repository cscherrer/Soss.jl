import LogDensityProblems: logdensity
using ResumableFunctions

export arguments, args, stochastic, observed, parameters, supports
export paramSupport


using MacroTools: striplines, flatten, unresolve, resyntax, @q
using MacroTools
using StatsFuns
using DataStructures: counter

function arguments(model::Model)
    model.args
end

"A stochastic node is any `v` in a model with `v ~ ...`"
function stochastic(m::Model)
    nodes = []
    postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            union!(nodes, [v])
        else x
        end
    end
    nodes
end


"""
    parameters(m::Model)

A _parameter_ is a stochastic node that is only assigned once
"""
function parameters(m::Model)
    assignmentCount = counter([dep.second for dep in dependencies(m)])
    filter(stochastic(m)) do v
        assignmentCount[v] == 1
    end
end

export dependencies
function dependencies(m::Model)
    Parents = Vector{Symbol}
    Dep =  Pair{Parents, Symbol}

    result = Dep[]
    for v in m.args
        push!(result, [] => v)
    end
    vars = variables(m)
    postwalk(m.body) do x
        if @capture(x,v_~d_) || @capture(x,v_=d_)
            parents = findsubexprs(d,vars)
            if isempty(parents)
                push!(result, [] => v)
            else
                push!(result, (parents => v))
            end
        else x
        end
    end
    result
end

observed(m::Model) = setdiff(stochastic(m), parameters(m))

# export paramSupport
# function paramSupport(model)
#     supps = Dict{Symbol, Any}()
#     postwalk(model.body) do x
#         if @capture(x, v_ ~ dist_(args__))
#             if v in parameters(model)
#                 supps[v] = support(eval(dist))
#             end
#         else x
#         end
#     end
#     return supps
# end

# function xform(R, v, supp)
#     @assert typeof(supp) == RealInterval
#     lo = supp.lb
#     hi = supp.ub
#     body = begin
#         if (lo,hi) == (-Inf, Inf)  # no transform needed in this case
#             quote
#                 $v = $R
#             end
#         elseif (lo,hi) == (0.0, Inf)
#             quote
#                 $v = softplus($R)
#                 ℓ += abs($v - $R)
#             end
#         elseif (lo, hi) == (0.0, 1.0)
#             quote
#                 $v = logistic($R)
#                 ℓ += log($v * (1 - $v))
#             end
#         else
#             throw(error("Transform not implemented"))
#         end
#     end
#     return body
# end


export logdensity
function logdensity(model;ℓ=:ℓ,par=:par,data=:data)
    body = postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
            if v ∈ parameters(model)
                @q begin
                    $v = $par.$v
                    $ℓ += logpdf($dist, $v)
                end
            else
                @q begin
                    $ℓ += logpdf($dist, $v)
                end
            end

        else x
        end
    end
    # print(body |> dump)
    for v in arguments(model)
        pushfirst!(body.args, :($v = data.$v))
    end
    result = @q function($par, $data)
        $ℓ = 0.0

        $body
        return $ℓ
    end

    flatten(result)
end



# Note: `getTransform` currently assumes supports are not parameter-dependent
export getTransform
function getTransform(model)
    expr = Expr(:tuple)
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_(args__))
            if v ∈ parameters(model)
                t = fromℝ(@eval $dist())
                # eval(:(t = fromℝ($dist)))
                push!(expr.args,:($v=$t))
            else x
            end
        else x
        end
    end
    return as(eval(expr))
end

# const locationScaleDists = [:Normal]

# export uncenter
# function uncenter(model)
#     body = postwalk(model.body) do x
#         if @capture(x, dist_(μ_,σ_)) && dist ∈ locationScaleDists
#             @q ($dist() >>= (x -> (Delta($σ*x + $μ))))
#         else x
#         end
#     end
#     Model(model.args, body)
# end

function symbols(expr)
    result = []
    postwalk(expr) do x
        if @capture(x, s_symbol_Symbol)
            union!(result, [s])
        end
    end
    result
end

export findsubexprs
function findsubexprs(expr, vs)
    intersect(symbols(expr), vs)
end

export prior
function prior(m :: Model)
    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            if v ∈ parameters(m)
                x
            else Nothing
            end
        else x
        end
    end
    Model(setdiff(arguments(m),observed(m)), body) |> pretty
end

export freeVariables
function freeVariables(m::Model)
    setdiff(arguments(m), stochastic(m))
end

# export priorPredictive
# function priorPredictive(m :: Model)
#     args = copy(m.args)
#     body = postwalk(m.body) do x
#         if @capture(x, v_ ~ dist_)
#             setdiff!(args, [v])
#             x
#         elseif @capture(x, v_ ⩪ dist_)
#             setdiff!(args, [v])
#             @q ($v ~ $dist)
#         else x
#         end
#     end
#     Model(args, body)
# end

export likelihood
function likelihood(m :: Model)
    m = annotate(m)
    args = copy(m.args)
    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            union!(args, [v])
            Nothing
        elseif @capture(x, v_ ⩪ dist_)
            setdiff!(args, [v])
            @q ($v ~ $dist)
        else x
        end
    end
    Model(args, body) |> pretty
end


export annotate
function annotate(m::Model)
    newbody = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            if v ∈ observed(m)
                @q $v ⩪ $dist
            else
                x
            end
        else x
        end
    end

    Model(args = m.args, body=newbody, meta = m.meta)
end

export variables
function variables(m::Model)
    vars = copy(m.args)
    postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            union!(vars, [Symbol(v)])
        elseif @capture(x, v_ ⩪ dist_)
            union!(vars, [Symbol(v)])
        elseif @capture(x, v_ = dist_)
            union!(vars, [Symbol(v)])
        else x
        end
    end
    vars
end

isNothing(x) = (x == Nothing)

rmNothing(x) = x

function rmNothing(x::Expr)
  # Do not strip the first argument to a macrocall, which is
  # required.
  if x.head == :macrocall && length(x.args) >= 2
    Expr(x.head, x.args[1:2]..., filter(x->!isNothing(x), x.args[3:end])...)
  else
    Expr(x.head, filter(x->!isNothing(x), x.args)...)
  end
end

export stripNothing
stripNothing(ex::Expr) = prewalk(rmNothing, ex)
stripNothing(m::Model) = Model(m.args, stripNothing(m.body))

export pretty
pretty = stripNothing ∘ striplines ∘ flatten

export expandinline
function expandinline(m::Model)
    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            if typeof(eval(dist)) == Model
                Let
            end

            println(v)
            println(dist)
            println(typeof(eval(dist)))
        else x
        end
    end
    body
end

export expandSubmodels
function expandSubmodels(m :: Model)
    newbody = postwalk(m.body) do x
        if @capture(x, @model expr__)
            eval(x)
        else x
        end
    end
    Model(args=m.args, body=newbody, meta=m.meta)
end

function fold(leaf, expr) 
    function go(ast)
        @match ast begin
            Expr(head, arg1, newargs...) => expr(head, arg1, map(go, newargs))
            x                            => leaf(x)
        end
    end

    return go
end

# Example usage:
# --------------
# function leafCount(ast)
#     leaf(x) = 1
#     expr(head, arg1, newargs) = sum(newargs)
#     fold(leaf, expr)(ast)
# end

# leaves = begin
#     leaf(x) = [x]
#     expr(head, arg1, newargs) = union(newargs...)
#     fold(leaf, expr)
# end

# ast = :(f(x + 3y))

# leaves(ast)

