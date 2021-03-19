
export logdensity

using NestedTuples: lazymerge
import MeasureTheory

function MeasureTheory.logdensity(c::ConditionalModel{A,B,M}, x=NamedTuple()) where {A,B,M}
    _logdensity(M, Model(c), argvals(c), observations(c), x)
end

export sourceLogdensity

sourceLogdensity(m::AbstractModel) = sourceLogdensity()(Model(m))

function sourceLogdensity()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        # proc(_m, st :: Sample)     = :(_ℓ += logdensity($(st.rhs), $(st.x)))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            rhs = st.rhs
            @q begin
                _ℓ += logdensity($rhs, $x)
                $x = Soss.predict($rhs, $x)
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

# MeasureTheory.logdensity(d::Distribution, val, tr) = logpdf(d, val)


@gg function _logdensity(_::Type{M}, _m::Model, _args, _data, _pars) where M <: TypeLevel{Module}
    body = type2model(_m) |> sourceLogdensity() |> loadvals(_args, _data, _pars)
    @under_global from_type(M) @q let M
        $body
    end
end
