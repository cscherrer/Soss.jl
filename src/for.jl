using Distributions
import Distributions.logpdf

export For
struct For{F,N,X} 
    f :: F  
    θ :: NTuple{N,Int}
end

For(f, θ::Int...) = For(f,θ)

function For(f::F, θ::NTuple{N,Int}) where {F,N}
    X = f.(ones(Int, N)...) |> eltype
    For{F,N,X}(f,θ)
end

export rand

function Base.rand(dist::For) 
    map(CartesianIndices(dist.θ)) do I
        (rand ∘ dist.f)(Tuple(I)...)
    end
end

using Base.Cartesian


export logpdf


@inline function logpdf(d::For{F,N,X},xs::AbstractArray{X,N}) where {F,N, X}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logpdf(d.f(Tuple(θ)...), xs[θ])
    end
    s
end

@inline function importanceSample(p::For{F1,N,X}, q::For{F2,N,X}) where {F1,F2,N,X}
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

# using Transducers
# using Transducers: @next, complete
# function Transducers.__foldl__(rf, val, d::For)
#     for θ in d.θ
#         val = @next(rf, val, f(θ))
#     end
#     return complete(rf, val)
# end
