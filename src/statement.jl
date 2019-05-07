using MLStyle

abstract type Statement end

struct Let <: Statement
    name :: Symbol
    value
end

struct Follows <: Statement
    name :: Symbol
    dist 
end

function convert(Statement, expr::Expr)
    @match expr begin
        :($x ~ $dist)  => Follows(x, dist)
        :($x = $value) => Let(x, value)
    end
end