using .Bijectors

struct Transform{N,T} <: Bijector{N}
    t::T

    function Transform(t::T) where {T <:  TransformVariables.TransformTuple}
        new{t.dimension, T}(t)
    end
end

function (b::Transform{N,T})(x::NamedTuple) where {N,T <: TransformVariables.AbstractTransform}
    inverse(b.t, x)
end

function (b::Inverse{<: Transform{N,T}})(y::AbstractVector) where {N,T <:  TransformVariables.AbstractTransform}
    b.orig.t(y)
end

Bijectors.bijector(d::JointDistribution) = Transform(xform(d))

function Bijectors.logabsdetjac(b::Transform, x::NamedTuple)
    -transform_and_logjac(b.t, b.t(x))[2]
end
