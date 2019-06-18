using MLStyle

abstract type Statement end


struct Let <: Statement
    x :: Symbol
    rhs
end

struct Follows <: Statement
    x :: Symbol
    rhs 
end

struct Return <: Statement
    rhs 
end

struct LineNumber <: Statement
    node :: LineNumberNode
end

Statement(x) = convert(Statement, x)

function convert(::Type{Statement}, expr :: Expr)
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

import Base.convert 

convert(::Type{Statement}, node :: LineNumberNode) = LineNumber(node)

