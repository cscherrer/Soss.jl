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
    print(io, convert(Expr, m))
end

convert(::Type{Expr}, st::Follows) = :($(st.name) ~ $(st.value))
convert(::Type{Expr}, st::Let) = :($(st.name) = $(st.value))
convert(::Type{Expr}, st::LineNumber) = st.node
convert(::Type{Expr}, st::Return) = :(return $(st.value))

function convert(::Type{Expr}, sts::Vector{Statement})
    Expr(:block, [convert(Expr, st) for st in sts]...)
end

function convert(::Type{Expr}, m::Model)
    numArgs = length(m.args)
    args = if numArgs == 1
       m.args[1]
    elseif numArgs > 1
        Expr(:tuple, [x for x in m.args]...)
    end
    q = @q begin
        @model $(args) $(convert(Expr, m.body))
    end
    striplines(q).args[1]
end

dropLines(l::Let)        = [l]
dropLines(l::Follows)    = [l]
dropLines(l::Return)     = [l]
dropLines(l::LineNumber) = []

export dropLines
dropLines(m::Model) = begin
    newbody = cat(dropLines.(m.body)..., dims=1)
    Model(m.args, newbody)
end
