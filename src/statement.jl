using MLStyle

abstract type Statement end

struct Assign <: Statement
    x :: Symbol
    rhs
end

struct Sample <: Statement
    x :: Symbol
    rhs 
end

struct Observe <: Statement
    x :: Symbol
    rhs 
end

struct LineNumber <: Statement
    node :: LineNumberNode
end

struct Return <: Statement
    rhs :: Union{Symbol, Expr}
end

Statement(x) = convert(Statement, x)

function Statement(m::Model, x::Symbol)
    x ∈ keys(m.vals) && return Assign(x,m.vals[x])
    if x ∈ keys(m.dists) 
        x ∈ keys(m.data) && return Observe(x, m.dists[x])
        return Sample(x,m.dists[x])
    end
end

function Base.convert(::Type{Statement}, expr :: Expr)
    @match expr begin
        :($x ~ $dist)  => Sample(x, dist)
        :($x = $value) => Assign(x, value)
    end
end

varName(st :: Sample)     = st.x
varName(st :: Observe)    = st.x
varName(st :: Assign)     = st.x
varName(st :: Return)     = nothing
varName(st :: LineNumber) = nothing
varName(::Nothing)        = nothing


Base.convert(::Type{Statement}, node :: LineNumberNode) = LineNumber(node)

Base.convert(::Type{Expr}, st::Sample)     = :($(st.x) ~ $(st.rhs))
Base.convert(::Type{Expr}, st::Observe)    = :($(st.x) ⩪ $(st.rhs))
Base.convert(::Type{Expr}, st::Assign)     = :($(st.x) = $(st.rhs))
Base.convert(::Type{Expr}, st::Return)     = :(return $(st.rhs))
Base.convert(::Type{Expr}, st::LineNumber) = st.node

function Base.convert(::Type{Expr}, sts::Vector{Statement})
    Expr(:block, [convert(Expr, st) for st in sts]...)
end

Expr(m::Model,v) = convert(Expr,Statement(m,v) )