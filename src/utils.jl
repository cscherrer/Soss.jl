import LogDensityProblems: logdensity
using ResumableFunctions

export arguments, args, stochastic, observed, parameters, rand, supports, logdensity
export paramSupport


using MacroTools: striplines, flatten, unresolve, resyntax, @q
using MacroTools
using StatsFuns


pretty = stripNothing ∘ striplines ∘ flatten

function arguments(model::Model)
    model.args
end

"A stochastic node is any `v` in a model with `v ~ ...`"
function stochastic(model::Model)
    nodes = []
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
            union!(nodes, [v])
        elseif @capture(x, v_ ⩪ dist_)
            union!(nodes, [v])
        else x
        end
    end
    nodes
end



function parameters(model::Model)
    pars = []
    for line in model.body.args
        if @capture(line, v_ ~ dist_)
            union!(pars, [v])
        end
    end
    pars
end

observed(model::Model) = setdiff(stochastic(model), parameters(model))

function paramSupport(model)
    supps = Dict{Symbol, Any}()
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_(args__))
            if v in parameters(model)
                supps[v] = support(eval(dist))
            end
        else x
        end
    end
    return supps
end

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


function logdensity(model)
    result = @q function(par, data)
        ℓ = 0.0
    end

    body = result.args[2].args
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
            push!(body, :($v = par.$v))
            push!(body, :(ℓ += logpdf($dist, $v)))
        elseif @capture(x, v_ ⩪ dist_)
            push!(body, :($v = data.$v))
            push!(body, :(ℓ += logpdf($dist, $v)))
        else x
        end
    end

    push!(body, :(return ℓ))
    result
end


export getTransform
function getTransform(model)
    expr = Expr(:tuple)
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
            # println(dist)
            eval(:(t = fromℝ($dist)))
            push!(expr.args,:($v=$t))
        else x
        end
    end
    return as(eval(expr))
end

const locationScaleDists = [:Normal]

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

export findsubexprs

function findsubexprs(ex, vs)
    result = Set()
    MacroTools.postwalk(ex) do y
      y in vs && push!(result, y)
    end
    return result
end

export prior
function prior(m :: Model)
    body = postwalk(m.body) do x
        if @capture(x, v_ ⩪ dist_)
            Nothing
        else x
        end
    end
    Model(setdiff(arguments(m),observed(m)), body) |> pretty
end

export freeVariables
function freeVariables(m::Model)
    setdiff(arguments(m), stochastic(m))
end

export priorPredictive
function priorPredictive(m :: Model)
    args = copy(m.args)
    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            setdiff!(args, [v])
            x
        elseif @capture(x, v_ ⩪ dist_)
            setdiff!(args, [v])
            @q ($v ~ $dist)
        else x
        end
    end
    Model(args, body)
end

export likelihood
function likelihood(m :: Model)
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

export variables
function variables(m::Model)
    [freeVariables(m); parameters(m); observed(m)]
    # vars = copy(m.args)
    # postwalk(m.body) do x
    #     if @capture(x, v_ ~ dist_)
    #         push!(vars, Symbol(v))
    #     elseif @capture(x, v_ ⩪ dist_)
    #         push!(vars, Symbol(v))
    #     elseif @capture(x, v_ = dist_)
    #         push!(vars, Symbol(v))
    #     else x
    #     end
    # end
    # vars
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
