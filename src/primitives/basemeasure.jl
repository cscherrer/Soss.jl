
export basemeasure

import MeasureTheory

function MeasureTheory.basemeasure(c::ConditionalModel{A,B,M}, x=NamedTuple()) where {A,B,M}
    _basemeasure(M, Model(c), argvals(c), observations(c), x)
end

export sourceBasemeasure

sourceBasemeasure(m::AbstractModel) = sourceBasemeasure()(Model(m))

function sourceBasemeasure()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            xname = QuoteNode(x)
            rhs = st.rhs
            @q begin
                _bm = merge(_bm, NamedTuple{($xname,)}((basemeasure($rhs),)))
                $x = Soss.predict($rhs, $x)
            end
        end

        wrap(kernel) = @q begin
            _bm = (;)
            $kernel
            return ProductMeasure(_bm)
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end


@gg M function _basemeasure(_::Type{M}, _m::Model, _args, _data, _pars) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceBasemeasure() |> loadvals(_args, _data, _pars))
end
