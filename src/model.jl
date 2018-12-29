export Model, convert, @model

Base.@kwdef struct Model
    args :: Vector{Symbol}     = []
    body :: Expr               = @q begin end
    meta :: Dict{Symbol, Any}  = Dict()
end

Model(args::Vector{Symbol}, body::Expr) = expandSubmodels(Model(args=args, body=body))

(m::Model)(v::Symbol) = begin
    args = copy(m.args)
    push!(args, v)
    Model(args, m.body)
end

(m::Model)(vs...) = begin
    args = copy(m.args)
    union!(args, vs)
    Model(args, m.body)
end

(m::Model)(;kwargs...) = begin
    result = deepcopy(m)
    args = result.args
    body = result.body
    setdiff!(args, keys(kwargs))
    assignments = [:($k = $v) for (k,v) in kwargs]
    pushfirst!(body.args, assignments...)
    Model(args, body)
end

macro model(vs::Expr,body::Expr)
    @assert vs.head == :tuple
    Model(Vector{Symbol}(vs.args), pretty(body)) |> expandSubmodels
end

macro model(v::Symbol,body::Expr)
    Model([v], pretty(body)) |> expandSubmodels
end

macro model(body :: Expr)
    Model(body = pretty(body)) |> expandSubmodels
end

# function getproperty(m::Model, key::Symbol)
#     if key ∈ [:args, :body, :meta]
#         m.key
#     else
#         get!(m.meta, key, eval(Expr(:call, key, m)))
#     end
# end

import Base.convert
convert(Expr, m::Model) = begin
    func = @q function($(m.args),) $(m.body) end
    pretty(func)
end

convert(::Type{Any},m::Model) = println(m)

function Base.show(io::IO, m::Model) 
    print(io, "@model ")
    numArgs = length(m.args)
    if numArgs == 1
        print(m.args[1], " ")
    elseif numArgs > 1
        print(io, "$(Expr(:tuple, [x for x in m.args]...)) ")
    end
    print(io, m.body)
end
