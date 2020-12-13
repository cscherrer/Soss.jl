using Reexport

using MLStyle
using Distributions


# In Bijectors.jl,
# logpdf_with_trans(dist, x, true) == logpdf(transformed(dist), link(dist, x))


export xform


function xform(m::ConditionalModel{A, B}) where {A,B}
    return _xform(getmoduletypencoding(m), Model(m), argvals(m), obs(m))
end

@gg M function _xform(_::Type{M}, _m::Model{Asub,B}, _args::A, _data) where {M <: TypeLevel{Module}, Asub, A,B}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceXform(_data) |> loadvals(_args, _data))
end

# function xform(m::Model{EmptyNTtype, B}) where {B}
#     return xform(m,NamedTuple())    
# end


export sourceXform

sourceXform(m::Model) = sourceXform()(m)

function sourceXform(_data=NamedTuple())
    function(_m::Model)

        _m = canonical(_m)

        _datakeys = getntkeys(_data)
        proc(_m, st::Assign)        = :($(st.x) = $(st.rhs))
        proc(_m, st::Return)     = nothing
        proc(_m, st::LineNumber) = nothing
        
        function proc(_m, st::Sample)
            if st.x ∈ _datakeys
                return :($(st.x) = _data.$(st.x))
            else
                return (@q begin
                    $(st.x) = rand($(st.rhs))
                    _t = xform($(st.rhs), _data)

                    _result = merge(_result, ($(st.x)=_t,))
                end)
            end
            
        end

        wrap(kernel) = @q begin
            _result = NamedTuple()
            $kernel
            $as(_result)
        end

        buildSource(_m, proc, wrap) |> flatten

    end
end

function xform(d, _data)
    if hasmethod(support, (typeof(d),))
        return asTransform(support(d)) 
    end

    error("Not implemented:\nxform($d)")
end

using TransformVariables: ShiftedExp, ScaledShiftedLogistic

function asTransform(supp:: RealInterval) 
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




function xform(d::For{T,NTuple{N,Int}}, _data)  where {N,T}
    xf1 = xform(d.f(getindex.(d.θ, 1)...), _data)
    return as(Array, xf1, d.θ...)
    
    # TODO: Implement case of unequal supports
end

function xform(d::For{T,NTuple{N,UnitRange{Int}}}, _data)  where {N,T}
    xf1 = xform(d.f(getindex.(d.θ, 1)...), _data)
    return as(Array, xf1, length.(d.θ)...)
    
    # TODO: Implement case of unequal supports
end


function xform(d::iid, _data)
    as(Array, xform(d.dist, _data), d.size...)
end

xform(d::MvNormal, _data=NamedTuple()) = as(Array, size(d))
