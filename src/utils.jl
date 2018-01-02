function parameters(model)
    params :: Vector{Symbol} = []
    body = postwalk(model) do x
        if @capture(x, v_ ~ dist_)
            push!(params, v)
        else x
        end
    end
    return params
end

function supports(model)
    supps = Dict{Symbol, Any}()
    postwalk(model) do x
        if @capture(x, v_ ~ dist_)
            supps[v] = support(eval(dist))
        else x
        end
    end
    return supps
end

function func(model, v :: Symbol)
    body = postwalk(model) do x 
        if @capture(x, $v ~ dist_)
            @q begin end
        else x
        end
    end

    fQuoted = :($v -> $body)

    return fQuoted
end 

function func(model, vs :: Vector{Symbol})
    body = postwalk(model) do x 
        if @capture(x, v_ ~ dist_) && v in vs
            ()
        else x
        end
    end

    fQuoted = quote
        $vs -> $body
    end

    return fQuoted
end 
