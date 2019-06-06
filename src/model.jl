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

function Base.show(io::IO, m::Model) 
    print(io, "@model ")
    indent = get(io, :indent, 0)
    numArgs = length(m.args)
    
    if numArgs == 1
        print(m.args[1], " ")
    elseif numArgs > 1
        print(io, "$(Expr(:tuple, [x for x in m.args]...)) ")
    end
    println(io, "begin")

    io2 = IOContext(io, :indent => indent + 1)
    for st in m.body
        print(io2, st)
    end
    print("end")

end

function Base.show(io :: IO, st :: Follows)
    indent = get(io, :indent, 0)
    print(repeat("    ",indent))
    print(io, st.name, " ~ ")
    printdist(io, st.value)
end

function Base.show(io :: IO, st :: Let)
    indent = get(io, :indent, 0)
    print(repeat("    ",indent))
    println(io, st.name, " = ", st.value)
    end

function Base.show(io :: IO, st :: LineNumber)
    return ()
    end

function Base.show(io, st :: Return)
    indent = get(io, :indent, 0)
    print(repeat("    ",indent))
    println("return ",value)
end


# function printdist(io, dist)
#     @match dist begin
