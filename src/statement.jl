using MLStyle

abstract type Statement end


struct Let <: Statement
    x :: Symbol
    rhs
end

struct Follows <: Statement
    x :: Symbol
    rhs :: RHS
end

struct Return <: Statement
    rhs 
end

struct LineNumber <: Statement
    node :: LineNumberNode
end

Statement(x) = convert(Statement, x)

function Base.convert(::Type{Statement}, expr :: Expr)
    @match expr begin
        :($x ~ $dist)  => Follows(x, dist)
        :($x = $value) => Let(x, value)
        :(return $x)   => Return(x)
    end
end

varName(st :: Follows)    = st.x
varName(st :: Let)        = st.x
varName(st :: Return)     = nothing
varName(st :: LineNumber) = nothing
varName(::Nothing)        = nothing


Base.convert(::Type{Statement}, node :: LineNumberNode) = LineNumber(node)



Base.convert(::Type{Expr}, st::Follows) = :($(st.x) ~ $(st.rhs))
Base.convert(::Type{Expr}, st::Let) = :($(st.x) = $(st.rhs))
Base.convert(::Type{Expr}, st::LineNumber) = st.node
Base.convert(::Type{Expr}, st::Return) = :(return $(st.rhs))

function Base.convert(::Type{Expr}, sts::Vector{Statement})
    Expr(:block, [convert(Expr, st) for st in sts]...)
end