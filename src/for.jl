using Distributions
import Distributions.logpdf
using Parameters

export For
struct For{F,N,T,X} 
    f :: F  
    θ :: NTuple{N,T}
end


function For(f::F, θ::T...) where {F,T}
    N = length(θ)
    X = f.(ones(N)...) |> eltype
    For{F,N,T,X}(f,θ)
end

function For(f::F, θ::NTuple{N,T}) where {N,F,T}
    X = f.(ones(N)...) |> eltype
    For{F,N,T,X}(f,θ)
end

export rand

function Base.rand(dist::For) 
    map(CartesianIndices(dist.θ)) do I
        (rand ∘ dist.f)(Tuple(I)...)
    end
end

using Base.Cartesian


export logpdf


@inline function logpdf(d::For{F,N,T},xs::AbstractArray{X,N}) where {F,N,T, X}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logpdf(d.f(Tuple(θ)...), xs[θ])
    end
    s
end

@inline function importanceSample(p::For{F1,N,T,X}, q::For{F2,N,T,X}) where {F1,F2,N,T,X}
    _ℓ = 0.0
    x = Array{X, N}(undef, length.(q.θ))
    @inbounds @simd for θ in CartesianIndices(q.θ)
        I = Tuple(θ)
        ℓx = importanceSample(p.f(I...), q.f(I...))
        _ℓ += ℓx.ℓ
        x[θ] = ℓx.val
    end
    Weighted(_ℓ,x)
end

using Transducers
using Transducers: @next, complete
function Transducers.__foldl__(rf, val, d::For)
    for θ in d.θ
        val = @next(rf, val, f(θ))
    end
    return complete(rf, val)
end
