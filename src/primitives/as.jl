using Reexport

using MLStyle
using NestedTuples
import NestedTuples
import MeasureTheory: testvalue

function NestedTuples.schema(::Type{TransformVariables.TransformTuple{T}}) where {T} 
    schema(T)
end

# In Bijectors.jl,
# logdensity_with_trans(dist, x, true) == logdensity_def(transformed(dist), link(dist, x))


export as

@inline as(m::ConditionalModel{A, B}, _data::NamedTuple) where {A,B} = as(m | _data)

@inline function as(m::ConditionalModel{A, B}) where {A,B}
    return _as(getmoduletypencoding(m), Model(m), argvals(m), observations(m))
end

# function as(m::Model{EmptyNTtype, B}) where {B}
#     return as(m,NamedTuple())    
# end


export sourceXform

sourceXform(m::Model) = sourceXform()(m)

function sourceXform(_data=NamedTuple())
    function(_m::Model)

        _datakeys = getntkeys(_data)
        proc(_m, st::Assign)        = :($(st.x) = $(st.rhs))
        proc(_m, st::Return)     = nothing
        proc(_m, st::LineNumber) = nothing
        
        function proc(_m, st::Sample)
            x = st.x
            xname = QuoteNode(x)
            rhs = st.rhs
            
            thecode = @q begin 
                _d = get(_data, $xname, nothing)
                if isnothing(_d) # xname is not defined in _data
                    _result = merge(_result, ($x = Soss.as($rhs),))
                elseif _d isa NamedTuple
                    _result = merge(_result, ($x = Soss.as($rhs, _d),))
                end
            end

            # Non-leaves might be referenced later, so we need to be sure they
            # have a value
            isleaf(_m, st.x) || pushfirst!(thecode.args, :($x = Soss.testvalue($rhs)))

            return thecode
        end


        wrap(kernel) = @q begin
            _result = NamedTuple()
            $kernel
            $as(_result)
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten

    end
end

using Distributions: support

@inline function as(d, _data::NamedTuple)
    if hasmethod(support, (typeof(d),))
        return asTransform(support(d)) 
    end

    error("Not implemented:\nas($d)")
end

using TransformVariables: ShiftedExp, ScaledShiftedLogistic

function asTransform(supp:: Dists.RealInterval) 
    (lb, ub) = (supp.lb, supp.ub)

    (lb, ub) == (-Inf, Inf) && (return asℝ)
    isinf(ub) && return ShiftedExp(true,lb)
    isinf(lb) && return ShiftedExp(false,lb)
    return ScaledShiftedLogistic(ub-lb, lb)
end

as(μ::AbstractMeasure,  _data::NamedTuple) = as(μ)

as(d::Dists.AbstractMvNormal, _data::NamedTuple = NamedTuple()) = TV.as(Array, size(d))

@gg function _as(M::Type{<:TypeLevel}, _m::Model{Asub,B}, _args::A, _data) where {Asub,A,B}
    body = type2model(_m) |> sourceXform(_data) |> loadvals(_args, _data)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end    
end

function as(d::Dists.Distribution{Dists.Univariate}, _data::NamedTuple=NamedTuple())
    sup = Dists.support(d)
    lo = isinf(sup.lb) ? -TV.∞ : sup.lb
    hi = isinf(sup.ub) ? TV.∞ : sup.ub
    as(Real, lo,hi)
end

function as(d::Dists.Product, _data::NamedTuple=NamedTuple())
    n = length(d)
    v = d.v
    as(Vector, as(v[1]), n)
end
