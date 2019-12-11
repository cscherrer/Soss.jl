import TransformVariables
using Bijectors

const TV = TransformVariables
const B = Bijectors

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

m = @model x,N begin
    μ ~ Normal()
    α ~ Normal()
    β ~ Normal()
    σ ~ HalfNormal()
    yhat = α .+ β .* x
    y ~ For(N) do j
            Normal(yhat[j], σ)
        end
end;

x = randn(5)
t = xform(m(x=x,N=5), NamedTuple())

b = Transform(t)

b(randn(B.dimension(b)))
