import TransformVariables
using Bijectors

const TV = TransformVariables

struct Transform{N,T} <: Bijector{N}
    t::T

    function Transform(t::T) where {T <: TV.TransformTuple}
        new{t.dimension, T}(t)
    end
end

function (b::Transform{N,T})(x) where {N,T <: TV.AbstractTransform}
    t(x) 
end



function (b::Inversed{<: Transform{N,T}})(y) where {N,T <: TV.AbstractTransform}
    inverse(b.t, y)
end

as(T, args...) = Transform(TV.as(T, args...))


#####################

using Soss

m = @model μ begin
x ~ Normal(μ,1)
end

t = xform(m(μ=10), NamedTuple())

b = Transform(t)

b(randn(1))