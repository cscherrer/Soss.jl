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

export getTransform
function getTransform(model)
    expr = Expr(:tuple)
    postwalk(model.body) do x
        if @capture(x, v_ ~ dist_)
            if v ∈ parameters(model)
                t = fromℝ(@eval $dist)
                # eval(:(t = fromℝ($dist)))
                push!(expr.args,:($v=$t))
            else x
            end
        else x
        end
    end
    return as(eval(expr))
end

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

export stripNothing
stripNothing(ex::Expr) = prewalk(rmNothing, ex)
stripNothing(m::Model) = Model(m.args, stripNothing(m.body))

export pretty
pretty = stripNothing ∘ striplines ∘ flatten
