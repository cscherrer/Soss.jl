using Reduce

Reduce.@subtype FakeReal <: Real
load_package(:scope)

R(x) = FakeReal(RExpr(x))

macro R(x)
    :($(esc(x)) = FakeReal(RExpr($(QuoteNode(x)))))
end

export reduce

function reduce(m::JointDistribution,x)
    return _reduce(getmoduletypencoding(m.model), m.model, m.args, x)
end

@gg M function _reduce(_::Type{M}, _m::Model, _args, _data) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceReduce() |> loadvals(_args, _data))
end

function sourceReduce()
    function(_m::Model)
        function proc(_m, st :: Assign)
            @q begin
                $(st.x) = RExpr($(st.rhs))
            end
        end
                        
        function proc(_m, st :: Sample)
            @q begin
                $(st.x) = FakeReal(RExpr($(QuoteNode(st.x))))
                _ℓ += $(reduce())
            end
                 = :(_ℓ += reduce($(st.rhs), $(st.x)))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end

# julia> Algebra.optimize(:(z = a^2*b^2+10*a^2*m^6+a^2*m^2+2*a*b*m^4+2*b^2*m^6+b^2*m^2))
# quote
#     g23 = b * a
#     g27 = m * m
#     g24 = g27 * b * b
#     g25 = g27 * a * a
#     g26 = g27 * g27
#     z = g24 + g25 + g23 * (2g26 + g23) + g26 * (2g24 + 10g25)
# end

# Algebra.sum(:(1/((p+(k-1)*q)*(p+k*q))),:k,1,:(n+1))