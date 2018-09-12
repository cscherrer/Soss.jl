export Model, convert

struct Model
    args :: Set{Symbol}
    body :: Expr
end

(m::Model)(;kwargs...) = begin
    result = deepcopy(m)
    setdiff!(result.args, keys(kwargs))
    assignments = [:($k = $v) for (k,v) in kwargs]
    pushfirst!(result.body.args, assignments...)
    result
end


macro model(vs::Expr,ex)
    Model(Set(vs.args), pretty(ex))
end

macro model(v::Symbol,ex)
    Model(Set([v]), pretty(ex))
end

macro model(ex)   
    Model(Set(),pretty(ex))
end

import Base.convert
convert(Expr, m::Model) = begin
    func = @q function($(m.args),) $(m.body) end
    pretty(func)
end

Base.show(io::IO, m::Model) = begin
    print(io, "@model $(Expr(:tuple, [x for x in m.args]...)) ")
    println(io, m.body)
end

"""
    observe(model, var)
"""
function observe(model, v :: Symbol)
    k = args(model)
    if v ∉ k
        push!(k, v)
    end
    body = postwalk(model.body) do x 
        if @capture(x, $v ~ dist_)
            quote 
                $v ≅ $dist
            end
        else 
            x
        end
    end
    Model(k, body)

end 

function observe(model, vs :: Vector{Symbol})
    if @capture(model, function(args__) body_ end)
        args = union(args, vs)
    else 
        args = vs
    end

    body = postwalk(body) do x 
        if @capture(x, v_ ~ dist_) && v in vs
            quote 
                $v <~ $dist
            end
        else 
            x
        end
    end

    fQuoted = Expr(:function, :(($(args...),)), body)

    return pretty(fQuoted)
end 
