using Distributions
import Distributions.logpdf
# using Parameters

export For
struct For{F,N,T} 
    f :: F  
    θ :: NTuple{N,T}
end


function For(f::F, θ::T...) where {F,T <: AbstractRange}
    For{F,length(θ),  T}(f,θ)
end

export rand

function Base.rand(dist::For{F,N,T}) where {F,N,T <: AbstractRange}
    map(CartesianIndices(dist.θ)) do I
        (rand ∘ dist.f)(Tuple(I)...)
    end
end

using Base.Cartesian


export logpdf


@inline function logpdf(d::For{F,N,T},xs::AbstractArray{X,N}) where {F,N,T <: AbstractRange, X}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logpdf(d.f(Tuple(θ)...), xs[θ])
    end
    s
end

# using Transducers
# using Transducers: @next, complete
# function Transducers.__foldl__(rf, val, d::For)
#     for θ in d.θ
#         val = @next(rf, val, f(θ))
#     end
#     return complete(rf, val)
# end
