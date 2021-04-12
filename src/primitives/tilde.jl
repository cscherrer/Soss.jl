
export tilde

@inline function tilde(m::ASTModel)
    return _tilde(getmoduletypencoding(m), m)
end

# @inline function Base.tilde(m::ConditionalModel) 
#     tilde(GLOBAL_RNG, m)
# end

# @inline function Base.tilde(m::DAGModel)
#     return _tilde(getmoduletypencoding(m), m, NamedTuple())(rng)
# end

# tilde(m::DAGModel) = tilde(GLOBAL_RNG, m)



# sourcetilde(m::DAGModel) = sourcetilde()(m)
# sourcetilde(jd::ConditionalModel) = sourcetilde(jd.model)

export sourcetilde
function sourcetilde() 
    function(_m::ASTModel)
        quote
            f -> let ~ = f 
                $(_m.body)
        end
        end
    end
end

@gg function _tilde(M::Type{<:TypeLevel}, _m::ASTModel)
    body = type2model(_m) |> sourcetilde()
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end

# @gg function _tilde(M::Type{<:TypeLevel}, _m::DAGModel, _args::NamedTuple{()})
#     body = type2model(_m) |> sourcetilde()
#     @under_global from_type(_unwrap_type(M)) @q let M
#         $body
#     end
# end
