export arguments, args, stochastic, observed, parameters, rand, supports
export paramSupport

using MacroTools: striplines, flatten, unresolve, resyntax, @q
using MacroTools
using StatsFuns


pretty = striplines


"A stochastic node is any `v` in a model with `v ~ ...`"
function stochastic(model)
    nodes = Set{Symbol}()
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
            union!(nodes, [v])
        else x 
        end
    end
    nodes
end



function parameters(model)
    pars = Set{Symbol}()
    for line in model.body.args
        if @capture(line, v_ ~ dist_)
            union!(pars, [v])
        end
    end
    pars
end

observed(model) = setdiff(stochastic(model), parameters(model))

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

function xform(R, v, supp)
    @assert typeof(supp) == RealInterval
    lo = supp.lb
    hi = supp.ub
    body = begin
        if (lo,hi) == (-Inf, Inf)  # no transform needed in this case
            quote
                $v = $R
            end
        elseif (lo,hi) == (0.0, Inf)   
            quote
                $v = softplus($R)
                ℓ += abs($v - $R)
            end
        elseif (lo, hi) == (0.0, 1.0)
            quote 
                $v = logistic($R)
                ℓ += log($v * (1 - $v))
            end 
        else 
            throw(error("Transform not implemented"))                            
        end
    end
    return body
end

function logdensity(model)
    body = postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
                quote
                $v = par.$v
                    ℓ += logpdf($dist, $v)
                end |> unblock

        elseif @capture(x, v_ ⩪ dist_)
                quote
                $v = data.$v
                    ℓ += logpdf($dist, $v)
                end |> unblock
        else x
        end
    end

    fQuoted = quote
        function(par,data)
                ℓ = 0.0
                $body
                return ℓ
            end
    end |> unblock

    return pretty(fQuoted)
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

function mapbody(f,functionExpr)
    ans = deepcopy(functionExpr)
    ans.args[2] = f(ans.args[2])
    ans
end


sampleFrom(m) = eval(samp(m))



import Base.rand

export findsubexprs

function findsubexprs(ex, vs)
    result = Set()
    MacroTools.postwalk(ex) do y
      y in vs && push!(result, y)
    end
    return result
end




function rand(N::Int)
    function(m :: Model)
        if isempty(observed(m)) && isempty(m.args)
            body = postwalk(m.body) do x 
                if @capture(x, v_ ~ dist_)
                    @q begin
                        $v = rand($dist)
                        val = merge(val, ($v=$v,))
                    end
                else x
                end
            end

            getOne = @q begin
                () -> begin
                    val = NamedTuple()
                    $body
                    push!(ans,val)
                    val
                end
            end

            print(getOne)

            result = quote
                begin
                    ans = []
                    for n in 1:$N
                        val = NamedTuple()
                        $body
                        push!(ans,val)
                    end 
                    ans
                end
            end        

            eval(getOne)

        elseif m.args != []
            throw(ArgumentError("rand called with nonempty args(m) == $(args(m))"))
        elseif observed(m) != []
            throw(ArgumentError("rand called with nonempty observed(m) == $(observed(m))"))
        end
    end
end

export prior
function prior(m :: Model)
    body = postwalk(m.body) do x 
        if @capture(x, v_ ⩪ dist_)
            :()
        else x
        end
    end
    Model(m.args, body) 
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

export posteriorPredictive
function posteriorPredictive(m :: Model)
    args = copy(m.args)
    body = postwalk(m.body) do x 
        if @capture(x, v_ ~ dist_)
            union!(args, [v])
            :()
        elseif @capture(x, v_ ⩪ dist_)
            setdiff!(args, [v])
            @q ($v ~ $dist)
        else x
        end
    end
    Model(args, body) 
end

export variables
function variables(m::Model)
    vars = copy(m.args)
    postwalk(m.body) do x 
        if @capture(x, v_ ~ dist_)
            push!(vars, Symbol(v))
        elseif @capture(x, v_ ⩪ dist_)
            push!(vars, Symbol(v))
        elseif @capture(x, v_ = dist_)
            push!(vars, Symbol(v))
        else x
        end
    end
    vars
end