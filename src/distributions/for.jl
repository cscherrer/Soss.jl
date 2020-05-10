using Distributions
import Distributions.logpdf
using Base.Cartesian
using Base.Threads
using FillArrays

export logdensity
export rand

export For
struct For{F,T,D,X} 
    f :: F  
    θ :: T
end

#########################################################
# T <: NTuple{N,J} where {J <: Integer}
#########################################################

For(f, θ::J...) where {J <: Integer} = For(f,θ)

function For(f::F, θ::T) where {F, N, J <: Integer, T <: NTuple{N,J}}
    d = f.(Ones{Int}(N)...)
    D = typeof(d)
    X = eltype(d)
    For{F, NTuple{N,J}, D, X}(f,θ)
end

@inline function logdensity(d::For{F,T,D,X1},xs::AbstractArray{X2,N}) where {F, N, J <: Integer, T <: NTuple{N,J}, D,  X1,  X2}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logdensity(d.f(Tuple(θ)...), xs[θ])
    end
    s
end

function Base.rand(dist::For) 
    map(CartesianIndices(dist.θ)) do I
        (rand ∘ dist.f)(Tuple(I)...)
    end
end

#########################################################
# T <: NTuple{N,J} where {J <: AbstractUnitRange}
#########################################################

For(f, θ::J...) where {J <: AbstractUnitRange} = For(f,θ)

function For(f::F, θ::T) where {F, N, J <: AbstractRange, T <: NTuple{N,J}}
    d = f.(ones(Int, N)...)
    D = typeof(d)
    X = eltype(d)
    For{F, NTuple{N,J}, D, X}(f,θ)
end


@inline function logdensity(d::For{F,T,D,X1},xs::AbstractArray{X2,N}) where {F, N, J <: AbstractRange,  T <: NTuple{N,J}, D, X1, X2}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logdensity(d.f(Tuple(θ)...), xs[θ])
    end
    s
end


function Base.rand(dist::For{F,T}) where {F,  N, J <: AbstractRange, T <: NTuple{N,J}}
    map(CartesianIndices(dist.θ)) do I
        (rand ∘ dist.f)(Tuple(I)...)
    end
end

#########################################################
# T <: Base.Generator
#########################################################

function For(f::F, θ::T) where {F, T <: Base.Generator}
    d = f(θ.f(θ.iter[1]))
    D = typeof(d)
    X = eltype(d)
    For{F, T, D, X}(f,θ)
end


@inline function logdensity(d :: For{F,T}, x) where {F,T <: Base.Generator}
    s = 0.0
    for (θj, xj) in zip(d.θ, x)
        s += logdensity(d.f(θj), xj)
    end
    s
end

@inline function rand(d :: For{F,T,D,X}) where {F,T <: Base.Generator, D, X}
    rand.(Base.Generator(d.θ.f, d.θ.iter))
end

#########################################################










export logdensity2
@inline function logdensity2(d::For{F,N,X1},xs) where {F,N, X1, X2}
    results = zeros(eltype(xs), nthreads())

    θ = CartesianIndices(d.θ)

    total = Threads.Atomic{Float64}(0.0)
    @threads for tid in 1:nthreads()
        # split work
        start = 1 + ((tid - 1) * length(xs)) ÷ nthreads()
        stop = (tid * length(xs)) ÷ nthreads()
        domain = start:stop
        
        s = 0.0
        for j in domain
            @inbounds θj = θ[j]
            @inbounds s += logdensity(d.f(Tuple(θj)...), xs[θj])
        end

        Threads.atomic_add!(total, s)
    end

    total.value
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
