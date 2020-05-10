using TransformVariables
using Bijectors

struct Transform{N,T} <: Bijector{N}
    t::T

    function Transform(t::T) where {T <:  TransformVariables.TransformTuple}
        new{t.dimension, T}(t)
    end
end

function (b::Transform{N,T})(x) where {N,T <: TransformVariables.AbstractTransform}
    t(x) 
end

# function B.dimension(b::Transform{N,T}) where {N, T <:  TransformVariables.AbstractTransform}


function (b::Inversed{<: Transform{N,T}})(y) where {N,T <:  TransformVariables.AbstractTransform}
    inverse(b.t, y)
end



#################################


export logdensity_with_trans

function logdensityℝⁿ(m::JointDistribution{A0,A,B,M}, data::NamedTuple, x::AbstractVector) where {A0,A,B,M}
    _logdensityℝⁿ(M, m.model, m.args, data, x)
end

function logdensityℝⁿ(m::JointDistribution{A0,A,B,M},x::AbstractVector) where {A0,A,B,M}
    _logdensityℝⁿ(M, m.model, m.args, x)
end




@gg M function _logdensityℝⁿ(_::Type{M}, _m::Model, _args, _data, _x) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceLogpdfℝⁿ(_data) |> loadvals(_args, _data))
end

function sourceLogpdfℝⁿ(_data=NamedTuple())
    function(_m::Model)
        _m = canonical(_m)
        _datakeys = getntkeys(_data)

        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            xname = QuoteNode(x)

            x ∈ _datakeys && return :(_ℓ += logdensity($(st.rhs), $x))


            q = @q begin
                _j += 1
                $x = _x[_j]

                println($x)
                _ℓ += logdensity(transformed($(st.rhs)), $x)
            end
            
            return q
        end

        wrap(kernel) = @q begin
            _ℓ = 0.0
            _j = 0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end
