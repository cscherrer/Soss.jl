
export logdensity

function Distributions.logdensity(c::ConditionalModel{A,B,M}, x=NamedTuple()) where {A,B,M}
    _logdensity(M, Model(c), argvals(c), obs(c), x)
end

@gg M function _logdensity(_::Type{M}, _m::Model, _args, _data, _pars) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourcelogdensity() |> loadvals(_args, _data, _pars))
end

export sourcelogdensity

sourcelogdensity(m::AbstractModel) = sourcelogdensity()(Model(m))

function sourcelogdensity()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Sample)     = :(_ℓ += logdensity($(st.rhs), $(st.x)))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            rhs = st.rhs
            @q begin
                _ℓ += logpdf($rhs, $x)
                $x = predict($rhs, $x)
            end
        end

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

Distributions.logpdf(d::Distribution, val, tr) = logpdf(d, val)
