
toargs(vs :: Vector{Symbol}) = Tuple(vs)
toargs(vs :: NTuple{N,Symbol} where {N}) = vs

macro model(vs::Expr,expr::Expr)
    theModule = __module__
    @assert vs.head == :tuple
    @assert expr.head == :block
    ASTModel(theModule,Vector{Symbol}(vs.args), expr)
end

macro model(v::Symbol, expr::Expr)
    theModule = __module__
    ASTModel(theModule,[v], expr)
end

macro model(expr :: Expr)
    theModule = __module__
    ASTModel(theModule,Vector{Symbol}(), expr)
end

export @dagmodel

macro dagmodel(vs::Expr,expr::Expr)
    theModule = __module__
    @assert vs.head == :tuple
    @assert expr.head == :block
    DAGModel(theModule,Vector{Symbol}(vs.args), expr)
end

macro dagmodel(v::Symbol, expr::Expr)
    theModule = __module__
    DAGModel(theModule,[v], expr)
end

macro dagmodel(expr :: Expr)
    theModule = __module__
    DAGModel(theModule,Vector{Symbol}(), expr)
end
