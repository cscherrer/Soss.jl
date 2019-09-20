using Reexport

@reexport using DataFrames
using MLStyle
using Distributions



export xform


function xform(m::JointDistribution{A, B}, _data) where {A,B}
    return _xform(m.model, m.args, _data)    
end

@gg function _xform(_m::Model{Asub,B}, _args::A, _data) where {Asub, A,B} 
    type2model(_m) |> sourceXform(_data) |> loadvals(_args, _data)
end

# function xform(m::Model{EmptyNTtype, B}) where {B}
#     return xform(m,NamedTuple())    
# end


export sourceXform

function sourceXform(_data)
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
                    _t = xform($(st.rhs))

                    _result = merge(_result, ($(st.x)=_t,))
                end)
            end
            
        end

        wrap(kernel) = @q begin
            _result = NamedTuple()
            $kernel
            as(_result)
        end

        buildSource(_m, proc, wrap) |> flatten

    end
end




function xform(d)
    if hasmethod(support, (typeof(d),))
        return asTransform(support(d)) 
    end
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




function xform(d::For)
    # allequal(d.f.(d.θs)) && 
    return as(Array, xform(d.f(d.θs[1])), size(d.θs)...)
    
    # TODO: Implement case of unequal supports
    @error "xform: Unequal supports not yet supported"
end

function xform(d::iid)
    as(Array, xform(d.dist), d.size...)
end

xform(d::MvNormal) =  as(Vector, length(d))