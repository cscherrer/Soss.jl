using Reexport

using MLStyle
using NestedTuples
import NestedTuples
using TransformVariables



function NestedTuples.schema(::Type{TransformVariables.TransformTuple{T}}) where {T} 
    schema(T)
end

# In Bijectors.jl,
# logdensity_with_trans(dist, x, true) == logdensity(transformed(dist), link(dist, x))


export xform

xform(m::ConditionalModel{A, B}, _data::NamedTuple) where {A,B} = xform(m | _data)

function xform(m::ConditionalModel{A, B}) where {A,B}
    return _xform(getmoduletypencoding(m), Model(m), argvals(m), observations(m))
end

# function xform(m::Model{EmptyNTtype, B}) where {B}
#     return xform(m,NamedTuple())    
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
                _t = xform($rhs, get(_data, $xname, NamedTuple()))
                if !isnothing(_t)
                    _result = merge(_result, ($x=_t,))
                end
            end

            # Non-leaves might be referenced later, so we need to be sure they
            # have a value
            isleaf(_m, st.x) || pushfirst!(thecode.args, :($x = testvalue($rhs)))

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

function xform(d, _data::NamedTuple)
    if hasmethod(support, (typeof(d),))
        return asTransform(support(d)) 
    end

    error("Not implemented:\nxform($d)")
end

using TransformVariables: ShiftedExp, ScaledShiftedLogistic

function asTransform(supp:: Dists.RealInterval) 
    (lb, ub) = (supp.lb, supp.ub)

    (lb, ub) == (-Inf, Inf) && (return asℝ)
    isinf(ub) && return ShiftedExp(true,lb)
    isinf(lb) && return ShiftedExp(false,lb)
    return ScaledShiftedLogistic(ub-lb, lb)
end

# export xform
# xform(::Normal)       = asℝ
# xform(::Cauchy)       = asℝ
# xform(::Flat)         = asℝ

# xform(::HalfCauchy)   = asℝ₊
# xform(::HalfNormal)   = asℝ₊
# xform(::HalfFlat)     = asℝ₊
# xform(::InverseGamma) = asℝ₊
# xform(::Gamma)        = asℝ₊
# xform(::Exponential)  = asℝ₊

# xform(::Beta)         = as𝕀
# xform(::Uniform)      = as𝕀

xform(d, _data) = nothing

# TODO: Convert this to use `ProductMeasure`
# function xform(d::For{T,NTuple{N,Int}}, _data)  where {N,T}
#     xf1 = xform(d.f(getindex.(d.θ, 1)...), _data)
#     return as(Array, xf1, d.θ...)
    
#     # TODO: Implement case of unequal supports
# end

# TODO: Convert this to use `ProductMeasure`
# function xform(d::For{T,NTuple{N,UnitRange{Int}}}, _data::NamedTuple)  where {N,T}
#     xf1 = xform(d.f(getindex.(d.θ, 1)...), _data)
#     return as(Array, xf1, length.(d.θ)...)
    
#     # TODO: Implement case of unequal supports
# end

# TODO: Convert this to use `ProductMeasure`
# function xform(d::iid, _data::NamedTuple)
#     as(Array, xform(d.dist, _data), d.size...)
# end

# xform(d::MvNormal, _data::NamedTuple=NamedTuple()) = as(Array, size(d))

function xform(μ::AbstractMeasure,  _data::NamedTuple=NamedTuple())
    xform(representative(μ))
end

xform(μ::ProductMeasure) = as(Array, xform(first(μ.data)), size(μ.data)...)

using MeasureTheory

xform(::Lebesgue{ℝ}) = asℝ

xform(::Lebesgue{𝕀}) = as𝕀

xform(::Lebesgue{ℝ₊}) = asℝ₊  


@gg function _xform(M::Type{<:TypeLevel}, _m::Model{Asub,B}, _args::A, _data) where {Asub,A,B}
    body = type2model(_m) |> sourceXform(_data) |> loadvals(_args, _data)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end    
end
