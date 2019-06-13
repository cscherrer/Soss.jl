using MLStyle

abstract type Statement end


struct Let <: Statement
    name :: Symbol
    value
end

struct Follows <: Statement
    name :: Symbol
    value 
end

struct Return <: Statement
    value 
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

varName(st :: Follows)    = st.name
varName(st :: Let)        = st.name
varName(st :: Return)     = nothing
varName(st :: LineNumber) = nothing
varName(::Nothing)        = nothing

import Base.convert 

convert(::Type{Statement}, node :: LineNumberNode) = LineNumber(node)

