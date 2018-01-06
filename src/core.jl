macro model(v,ex)
    body = :(function($v,) $ex end)
    Expr(:quote, prettify(body))
end

macro model(ex)   
    body = :(function() $ex end)
    Expr(:quote, prettify(body))
end

"""
    observe(model, var)
"""
function observe(model, v :: Symbol)
    if @capture(model, function(args__) body_ end)
        if !(v in args)
            push!(args, v)
        end
    else 
        args = [v]
    end 

    body = postwalk(body) do x 
        if @capture(x, v0_ ~ dist_) && v0 == v
            quote 
                $v <~ $dist
            end
        else 
            x
        end
    end

    fQuoted = Expr(:function, :(($(args...),)), body)

    return prettify(fQuoted)
end 

function observe(model, vs :: Vector{Symbol})
    if @capture(model, function(args__) body_ end)
        args = union(args, vs)
    else 
        args = vs
    end 
         $v <~ $dist
            end
        else 
            x
        end
    end

    fQuoted = Expr(:function, :(($(args...),)), body)

    return prettify(fQuoted)
end 
