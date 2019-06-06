export Model, convert, @model
using MLStyle


abstract type AbstractModel end

struct Model <: AbstractModel
    args :: Vector{Symbol}
    body :: Vector{Statement}
end

function Model(vs :: Vector{Symbol}, expr :: Expr)
    body = [Statement(x) for x in expr.args]
    Model(vs, body)
end

macro model(vs::Expr,expr::Expr)
    @assert vs.head == :tuple
    @assert expr.head == :block
    Model(Vector{Symbol}(vs.args), expr)
end

macro model(v::Symbol, expr::Expr)
    Model([v], expr)
end

macro model(expr :: Expr)
    Model(Vector{Symbol}(), expr) 
end


(m::Model)(vs...) = begin
    args = m.args ∪ vs
    Model(args, m.body) |> condition(args...)
end


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
