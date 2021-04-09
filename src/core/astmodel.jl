struct ASTModel{A,B,M<:GeneralizedGenerated.TypeLevel} <: AbstractModel{A,B,M,Nothing,Nothing}
    args :: Vector{Symbol}
    body :: Expr
end

function ASTModel(theModule::Module, args::Vector{Symbol}, body::Expr)
    A = NamedTuple{Tuple(args)}

    B = to_type(body)
    M = to_type(theModule)
    return ASTModel{A,B,M}(args, striplines(body))
end

# ConditionalASTModel{A,B,M,Args,Obs} <: AbstractModel{A,B,M,Argvals,Obs}
#     model::ASTModel{A,B,M}
#     argvals :: Argvals
#     obs :: Obs
# end

function Base.convert(::Type{Expr}, m::ASTModel)
    numArgs = length(m.args)
    args = if numArgs == 1
       m.args[1]
    elseif numArgs > 1
        Expr(:tuple, [x for x in m.args]...)
    end

    body = m.body

    q = if numArgs == 0
        @q begin
            @model $body
        end
    else
        @q begin
            @model $(args) $body
        end
    end

    striplines(q).args[1] 
end

Base.show(io::IO, m :: ASTModel) = println(io, convert(Expr, m))
