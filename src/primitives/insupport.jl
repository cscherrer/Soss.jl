
export logdensityof

using NestedTuples: lazymerge
import MeasureTheory

import MeasureBase: insupport
export insupport

function MeasureBase.insupport(c::AbstractConditionalModel{A,B,M}, x=NamedTuple()) where {A,B,M}
    _insupport(M, model(c), argvals(c), observations(c), x)
end

export sourceInsupport

sourceInsupport(m::AbstractModel) = sourceInsupport()(model(m))

function sourceInsupport()
    function(_m::AbstractModel)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            rhs = st.rhs
            @q begin
                Soss.dynamic(Soss.insupport($rhs, $x)) || return false
                $x = Soss.predict($rhs, $x)
            end
        end

        wrap(kernel) = @q begin
            $kernel
            return true
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

# MeasureTheory.insupport(d::Distribution, val, tr) = logdensityof(d, val)


@gg function _insupport(M::Type{<:TypeLevel}, _m::AbstractModel, _args, _data, _pars)
    body = type2model(_m) |> sourceInsupport() |> loadvals(_args, _data, _pars)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end
