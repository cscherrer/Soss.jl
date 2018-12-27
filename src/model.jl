export Model, convert, @model

Base.@kwdef struct Model
    args :: Vector{Symbol}     = []
    body :: Expr               = @q begin end
    meta :: Dict{Symbol, Any}  = Dict()
end

(m::Model)(s) = begin
    result = deepcopy(m)
    push!(result.args, s)
    newbody = postwalk(result.body) do x
        if @capture(x, v_ ~ dist_) && (v ∈ [s])
            :($v ⩪ $dist)
        else x
        end
    end
    Model(result.args, newbody)
end

(m::Model)(vs...) = begin
    result = deepcopy(m)
    union!(result.args, vs)
    newbody = postwalk(result.body) do x
        if @capture(x, v_ ~ dist_) && (v ∈ vs)
            :($v ⩪ $dist)
        else x
        end
    end
    Model(result.args, newbody)
end

(m::Model)(;kwargs...) = begin
    result = deepcopy(m)
    setdiff!(result.args, keys(kwargs))
    assignments = [:($k = $v) for (k,v) in kwargs]
    pushfirst!(result.body.args, assignments...)
    newbody = postwalk(result.body) do x
        if @capture(x, v_ ~ dist_) && v in keys(kwargs)
            :($v ⩪ $dist)
        else x
        end
    end
    Model(result.args, newbody)
end

macro model(vs::Expr,ex)
    Model(vs.args, pretty(ex))
end

macro model(v::Symbol,ex)
    Model([v], pretty(ex))
end

macro model(ex :: Expr)
    Model([],pretty(ex))
end

function getproperty(m::Model, key::Symbol)
    if key ∈ [:args, :body, :meta]
        m.key
    else
        get!(m.meta, key, eval(Expr(:call, key, m)))
    end
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
