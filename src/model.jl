export Model, convert, @model
using MLStyle

abstract type AbstractModel end

struct Model <: AbstractModel
    args :: Vector{Symbol}
    vars :: Vector{Symbol}
    stoch :: Dict{Symbol, Any}
    bound :: Dict{Symbol, Any}
    retn
    
end

# Add a new line to a Model
function merge(m :: Model, expr :: Expr)
    @match expr begin
        :($x ~ $dist) => begin
            args = m.args
            vars = union(m.vars,[x])
            stoch = merge(m.stoch, Dict(x => dist))
            bound = m.bound
            retn = m.retn
            Model(args, vars, stoch, bound, retn)
        end

        :($x = $val) => begin
            args = m.args
            vars = union(m.vars,[x])
            stoch = m.stoch
            bound = merge(m.bound, Dict(x => val))
            retn = m.retn
            Model(args, vars, stoch, bound, retn)
        end

        :(return $x) => begin
            args = m.args
            vars = m.vars
            stoch = m.stoch
            bound = m.bound
            retn = x
            Model(args, vars, stoch, bound, retn)
        end
    end
end

macro model(vs::Expr,body::Expr)
    @assert vs.head == :tuple
    (stoch, bound, retn) = foldl(proc, body)
    Model(Vector{Symbol}(vs.args), pretty(body)) |> expandSubmodels
end

macro model(v::Symbol,body::Expr)
    Model([v], pretty(body)) |> expandSubmodels
end

macro model(body :: Expr)
    Model(Vector{Symbol}(), pretty(body)) |> expandSubmodels
end



function Model(args::Vector{Symbol}, body::Expr, meta::Dict{Symbol, Any})
    new(args, body, meta)
end

function Model(args::Vector{Symbol}, body::Expr)
    meta = Dict{Symbol, Any}()
    Model(args, body, meta)
end

Model(; args, body, meta) = Model(args, body, meta)

(m::Model)(vs...) = begin
    args = copy(m.args)
    union!(args, vs)
    Model(args, m.body) |> condition(args...)
end

# (m::Model)(;kwargs...) = begin
#     result = deepcopy(m)
#     args = result.args
#     body = result.body
#     vs = keys(kwargs)
#     setdiff!(args, vs)
#     assignments = [:($k = $v) for (k,v) in kwargs]
#     pushfirst!(body.args, assignments...)
#     stoch = stochastic(m)
#     Model(args, body) |> condition(vs...) |> flatten
# end

# inline for now
# TODO: Be more careful about this
(m::Model)(;kwargs...) = begin
    m = condition(keys(kwargs)...)(m)
    kwargs = Dict(kwargs)
    leaf(v) = get(kwargs, v, v)

    branch(head, newargs) = Expr(head, newargs...)
    body = foldall(leaf, branch)(m.body)
    Model(setdiff(m.args, keys(kwargs)), body)
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
