export Model, convert, @model
using MLStyle


abstract type AbstractModel end

struct Model{T} <: AbstractModel
    args :: Vector{Symbol}
    vars :: Vector{Symbol}
    body :: Vector{Statement}
    meta :: Dict{Symbol, Any}
end


function Model(vs :: Vector{Symbol}, expr :: Expr)
    body = filter([Statement(x) for x in expr.args]) do x
        !isnothing(x)
    end
    @show body
    vars = union(vs, [varName(s) for s in body]...)
    Model(Vector{Symbol}(vs.args), body)
end

# function Model(vs::Vector{Symbol}, body::Vector{Statement})

#     m = justArgs(vs)
#     # Add all the lines!
#     foldl(merge, body.args; init=justArgs(vs))
# end

macro model(vs::Expr,expr::Expr)
    @assert vs.head == :tuple
    @assert expr.head == :block
    Model(Vector{Symbol}(vs.args), expr)
    # Model(Vector{Symbol}(vs.args), pretty(body)) |> expandSubmodels
end

macro model(v::Symbol, expr::Expr)
    Model([v], expr)
end

macro model(expr :: Expr)
    Model(Vector{Symbol}(), expr) 
end


(m::Model)(vs...) = begin
    args = m.args ∪ vs
    vars = m.vars ∪ vs
    

    Model(args, m.vars, m.stoch, m.bound, m.retn) |> condition(args...)
end

# # (m::Model)(;kwargs...) = begin
# #     result = deepcopy(m)
# #     args = result.args
# #     body = result.body
# #     vs = keys(kwargs)
# #     setdiff!(args, vs)
# #     assignments = [:($k = $v) for (k,v) in kwargs]
# #     pushfirst!(body.args, assignments...)
# #     stoch = stochastic(m)
# #     Model(args, body) |> condition(vs...) |> flatten
# # end

# # inline for now
# # TODO: Be more careful about this
# (m::Model)(;kwargs...) = begin
#     m = condition(keys(kwargs)...)(m)
#     kwargs = Dict(kwargs)
#     leaf(v) = get(kwargs, v, v)

#     branch(head, newargs) = Expr(head, newargs...)
#     body = foldall(leaf, branch)(m.body)
#     Model(setdiff(m.args, keys(kwargs)), body)
# end

# # function getproperty(m::Model, key::Symbol)
# #     if key ∈ [:args, :body, :meta]
# #         m.key
# #     else
# #         get!(m.meta, key, eval(Expr(:call, key, m)))
# #     end
# # end

# import Base.convert
# convert(Expr, m::Model) = begin
#     func = @q function($(m.args),) $(m.body) end
#     pretty(func)
# end

# convert(::Type{Any},m::Model) = println(m)

function Base.show(io::IO, m::Model) 
    print(io, "@model ")
    numArgs = length(m.args)
    if numArgs == 1
        print(m.args[1], " ")
    elseif numArgs > 1
        print(io, "$(Expr(:tuple, [x for x in m.args]...)) ")
    end
    println(io, "begin")
    for (x,val) in m.bound
        println(x," = ",val)
    end
    for (x,dist) in m.stoch
        println(x," ~ ",dist)
    end
    println("end")

end

