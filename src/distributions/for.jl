using Distributions
import Distributions.logpdf
using Base.Cartesian
using Base.Threads
using FillArrays
using CuArrays
# using LoopVectorization

include("gpulogpdfs.jl")

export logpdf
export rand
export For


# struct For{X, N, D<:Sampleable{X}, P} <: Sampleable{AbstractArray{X, N}} # one would like to write this, but Distributions does not support such generality
struct For{X, N, D, P<:AbstractArray{T,N} where T}
    params :: P
end

Base.eltype(d::For{X,N,D}) where {X,N,D} = D
Distributions.params(d::For) = d.params

# This is general, refactor:
@inline function logpdf(d, xs::AbstractArray)
    sum(logpdf(eltype(d)).(Array(params(d)), xs))
end

@inline function logpdf(d, xs::CuArray)
    sum(logpdf(eltype(d)).(CuArray(params(d)), xs))
end

function Base.rand(d::For)
    map(d.params) do θ
        (rand ∘ eltype(d))(θ...)
    end
end


#########################################################
# T <: NTuple{N,J} where {J <: Integer}
#########################################################

For(f, dims::J...) where {J <: Integer} = For(f, dims)

function For(f, dims::T) where {N, J<:Integer, T<:NTuple{N,J}}
    α = one(CartesianIndex{N})
    d = f(Tuple(α)...)
    θ = params(d)
    θs = Array{typeof(θ),N}(undef, dims)
    θs[α] = θ
    @inbounds @simd for α in CartesianIndices(dims)[2:end] # Tried to use @avx here, but there are problems with GeneralizedGenerated. Should sometime understand and perhaps solve them.
        d = f(Tuple(α)...)
        θs[α] = params(d)
    end
    For{eltype(d),N,typeof(d),typeof(θs)}(θs)
end


#########################################################
# T <: NTuple{N,J} where {J <: AbstractUnitRange}
#########################################################

For(f, ranges::J...) where {J <: AbstractUnitRange} = For(f, ranges)

function For(f, ranges::T) where {N, J<:AbstractRange, T<:NTuple{N,J}}
    αs = CartesianIndices(ranges)
    α = αs[1]
    α₀ = α - one(CartesianIndex{N})
    d = f(Tuple(α)...)
    θ = params(d)
    θs = Array{typeof(θ),N}(undef, size(αs))
    θs[α - α₀] = θ
    @inbounds @simd for α in αs[2:end]
        d = f(Tuple(α)...)
        θs[α - α₀] = params(d)
    end
    For{eltype(d),N,typeof(d),typeof(θs)}(θs)
end


#########################################################
# T <: NTuple{N,J} where {J <: AbstractArray}
#########################################################

### From Michael Abbott's NamedPlus, which as things stand cannot be added because of compatibility restrictions:
const newaxis = [CartesianIndex()]
outer(xs::AbstractArray...) = outer(*, xs...)
function outer(f::Function, x::AbstractArray, ys::AbstractArray...)
    dims = ndims(x)
    views = map(ys) do y
        newaxes = ntuple(_->newaxis, dims)
        colons = ntuple(_->(:), ndims(y))
        view(y, newaxes..., colons...)
    end
    Broadcast.broadcast(f, x, views...)
end
###

For(f, ηs::T) where {N, T<:NTuple{N,AbstractArray}} = For(f, ηs...) # maybe this should be the one directly implemented, because of `canonical`. Ask!

function For(f, ηs::AbstractArray{T}...) where {T}
    d = f(((η -> zero(eltype(η))).(ηs))...) # just to figure out the distribution type and eltype
    ⨂ηs = outer(tuple, ηs...)
    θs = (η -> params(f(η...))).(⨂ηs)
    For{eltype(d),sum((length∘size).(ηs)),typeof(d),typeof(θs)}(θs)
end


#########################################################
# fallback to arrays assuming T is collectable
#########################################################

For(f, ηs...) = For(f, collect.(ηs)...)


#########################################################
# T <: Base.Generator
#########################################################

# function For(f::F, θ::T) where {F, T <: Base.Generator}
#     d = f(θ.f(θ.iter[1]))
#     D = typeof(d)
#     X = eltype(d)
#     For{F, T, D, X}(f,θ)
# end
#
#
# @inline function logpdf(d :: For{F,T}, x) where {F,T <: Base.Generator}
#     s = 0.0
#     for (θj, xj) in zip(d.θ, x)
#         s += logpdf(d.f(θj), xj)
#     end
#     s
# end
#
# @inline function rand(d :: For{F,T,D,X}) where {F,T <: Base.Generator, D, X}
#     rand.(Base.Generator(d.θ.f, d.θ.iter))
# end

#########################################################


# export logpdf2
# @inline function logpdf2(d::For{F,N,X1},xs) where {F,N, X1, X2}
#     results = zeros(eltype(xs), nthreads())
#
#     θ = CartesianIndices(d.θ)
#
#     total = Threads.Atomic{Float64}(0.0)
#     @threads for tid in 1:nthreads()
#         # split work
#         start = 1 + ((tid - 1) * length(xs)) ÷ nthreads()
#         stop = (tid * length(xs)) ÷ nthreads()
#         domain = start:stop
#
#         s = 0.0
#         for j in domain
#             @inbounds θj = θ[j]
#             @inbounds s += logpdf(d.f(Tuple(θj)...), xs[θj])
#         end
#
#         Threads.atomic_add!(total, s)
#     end
#
#     total.value
# end

# @inline function importanceSample(p::For{F1,N,X}, q::For{F2,N,X}) where {F1,F2,N,X}
#     _ℓ = 0.0
#     x = Array{X, N}(undef, length.(q.θ))
#     @inbounds @simd for θ in CartesianIndices(q.θ)
#         I = Tuple(θ)
#         ℓx = importanceSample(p.f(I...), q.f(I...))
#         _ℓ += ℓx.ℓ
#         x[θ] = ℓx.val
#     end
#     Weighted(_ℓ,x)
# end

# using Transducers
# using Transducers: @next, complete
# function Transducers.__foldl__(rf, val, d::For)
#     for θ in d.θ
#         val = @next(rf, val, f(θ))
#     end
#     return complete(rf, val)
# end
