using Distributions
import Distributions.logpdf
using Base.Cartesian
using Base.Threads
using FillArrays
using Random: GLOBAL_RNG

export logpdf
export rand

export For
struct For{F,T,D,X}
    f::F
    θ::T
end

function Base.size(d::For{F,T,D,X}) where {F,T,D,X}
    return size(CartesianIndices(d.θ))
end

function distribution_type(d::For{F,T,D,X}) where {F,T,D,X}
    return D
end


function Base.eltype(d::For{F,T,D,X}) where {F,T,D,X}
    return X
end

# function Base.collect(d::For{F,T,D,X}) where {F,T,D,X}
#     ind = CartesianIndices(d.θ)
#     dims = size(ind)
#     result = Array{D, length(dims)}(undef, dims)
#     @inbounds @simd for θ in ind
#         result[θ] = d.f(Tuple(θ)...)
#     end
#     return result
# end

Base.rand(dist::For) = rand(GLOBAL_RNG, dist)

#########################################################
# T <: NTuple{N,J} where {J <: Integer}
#########################################################

For(f, θ::J...) where {J<:Integer} = For(f, θ)

function For(f::F, θ::T) where {F,N,J<:Integer,T<:NTuple{N,J}}
    d = f.(Ones{Int}(N)...)
    D = typeof(d)
    X = eltype(d)
    return For{F,NTuple{N,J},D,X}(f, θ)
end

@inline function Distributions.logpdf(
    d::For{F,T,D,X1},
    xs::AbstractArray{X2,N},
) where {F,N,J<:Integer,T<:NTuple{N,J},D,X1,X2}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logpdf(d.f(Tuple(θ)...), xs[θ])
    end
    return s
end

function Base.rand(rng::AbstractRNG, dist::For)
    return map(CartesianIndices(dist.θ)) do I
        rand(rng, dist.f(Tuple(I)...))
    end
end

function Base.collect(d::For{F,T,D,X}) where {F,J<:Integer,N, T<:NTuple{N,J},D,X}
    ind = CartesianIndices(d.θ)
    dims = size(ind)
    result = Array{D, length(dims)}(undef, dims)
    @inbounds @simd for θ in ind
        result[θ] = d.f(Tuple(θ)...)
    end
    return result
end

#########################################################
# T <: NTuple{N,J} where {J <: AbstractUnitRange}
#########################################################

For(f, θ::J...) where {J<:AbstractUnitRange} = For(f, θ)

function For(f::F, θ::T) where {F,N,J<:AbstractRange,T<:NTuple{N,J}}
    d = f.(ones(Int, N)...)
    D = typeof(d)
    X = eltype(d)
    return For{F,NTuple{N,J},D,X}(f, θ)
end

@inline function Distributions.logpdf(
    d::For{F,T,D,X1},
    xs::AbstractArray{X2,N},
) where {F,N,J<:AbstractRange,T<:NTuple{N,J},D,X1,X2}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logpdf(d.f(Tuple(θ)...), xs[θ])
    end
    return s
end

function Base.rand(rng::AbstractRNG, dist::For{F,T}) where {F,N,J<:AbstractRange,T<:NTuple{N,J}}
    return map(CartesianIndices(dist.θ)) do I
        rand(rng, dist.f(Tuple(I)...))
    end
end

Base.rand(dist::For{F,T}) where {F,N,J<:AbstractRange,T<:NTuple{N,J}} = rand(GLOBAL_RNG, dist)

@inline function Base.collect(d::For{F,T,D,X}) where {F,N,J<:AbstractRange,T<:NTuple{N,J},D,X}
    ind = CartesianIndices(d.θ)
    dims = size(ind)
    result = Array{D, length(dims)}(undef, dims)
    @inbounds @simd for j in ind
        result[j] = d.f(Tuple(j)...)
    end
    return result
end

#########################################################
# T <: Base.Generator
#########################################################

function For(f::F, θ::T) where {F,T<:Base.Generator}
    d = f(θ.f(iterate(θ.iter)[1]))
    D = typeof(d)
    X = eltype(d)
    return For{F,T,D,X}(f, θ)
end

@inline function Distributions.logpdf(d::For{F,T}, x) where {F,T<:Base.Generator}
    s = 0.0
    for (θj, xj) in zip(d.θ, x)
        s += logpdf(d.f(θj), xj)
    end
    return s
end

@inline function Base.rand(rng::AbstractRNG, d::For{F,T,D,X}) where {F,T<:Base.Generator,D,X}
    return rand.(rng, Base.Generator(d.f ∘ d.θ.f, d.θ.iter))
end

@inline function Base.collect(d::For{F,T,D,X}) where {F,T<:Base.Generator,D,X}
    return collect(Base.Generator(d.f ∘ d.θ.f, d.θ.iter))
end


Base.rand(d::For{F,T,D,X}) where {F,T<:Base.Generator,D,X} = rand(GLOBAL_RNG, d)

#########################################################
# T <: AbstractArray
#########################################################

function For(f::F, θ::T) where {F,T<:AbstractArray}
    d = f(θ[1])
    D = typeof(d)
    X = eltype(d)
    return For{F,T,D,X}(f, θ)
end

@inline function Distributions.logpdf(d::For{F,T}, x) where {F,T<:AbstractArray}
    s = 0.0
    @inbounds @simd for j in eachindex(d.θ)
        s += logpdf(d.f(d.θ[j]), x[j])
    end
    return s
end

@inline function Base.rand(rng::AbstractRNG, d::For{F,T,D,X}) where {F,T<:AbstractArray,D,X}
    ind = CartesianIndices(d.θ)
    dims = size(ind)
    result = Array{X, length(dims)}(undef, dims)
    @inbounds @simd for j in ind
        result[j] = rand(d.f(d.θ[j]))
    end
    return result
end

function Base.collect(d::For{F,T,D,X}) where {F,T<:AbstractArray,D,X}
    ind = CartesianIndices(d.θ)
    dims = size(ind)
    result = Array{D, length(dims)}(undef, dims)
    @inbounds @simd for j in ind
        result[j] = d.f(d.θ[j])
    end
    return result
end

# @inline function Base.rand(rng::AbstractRNG, d::For{F,T,D,X}) where {F,T<:AbstractArray,D,X}
#     return rand.(d.f.(d.θ))
# end

Base.rand(d::For{F,T,D,X}) where {F,T<:AbstractArray,D,X} = rand(GLOBAL_RNG, d)

@inline function logpdf2(d::For{F,N,X1}, xs) where {F,N,X1,X2}
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
            @inbounds s += logpdf(d.f(Tuple(θj)...), xs[θj])
        end

        Threads.atomic_add!(total, s)
    end

    return total.value
end

@inline function importanceSample(p::For{F1,N,X}, q::For{F2,N,X}) where {F1,F2,N,X}
    _ℓ = 0.0
    x = Array{X,N}(undef, length.(q.θ))
    @inbounds @simd for θ in CartesianIndices(q.θ)
        I = Tuple(θ)
        ℓx = importanceSample(p.f(I...), q.f(I...))
        _ℓ += ℓx.ℓ
        x[θ] = ℓx.val
    end
    return Weighted(_ℓ, x)
end

# using Transducers
# using Transducers: @next, complete
# function Transducers.__foldl__(rf, val, d::For)
#     for θ in d.θ
#         val = @next(rf, val, f(θ))
#     end
#     return complete(rf, val)
# end
