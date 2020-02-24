using Distributions
import Distributions.logpdf
using Base.Cartesian
using Base.Threads
using FillArrays
using CuArrays
# using LoopVectorization

include("gpulogpdfs.jl")

# export logpdf
# export rand
export Product, For, iid


# Product of measures of type D, with parameters f.(params...)::AbstractArray{T,N} where T is the type of the parameters of D. Both For and iid will be particular cases.
# struct Product{D<:Sampleable{X} where X, P} <: Sampleable{AbstractArray{X,N}} # one would like to write this, but Distributions does not support such generality
struct Product{D, F, P} # P will be a parameter grid (NTuple of views)
    f :: F # cannot restrict this to be a `Function`, because `GeneralizedGenerated.Closure`s are not `Function`s. Also, it will be convenient to allow for `Nothing` here.
    params :: P
    Product{D}(f, params) where D = new{D, typeof(f), typeof(params)}(f, params)
end

Product{D}(f, params::Union{AbstractRange,AbstractArray}...) where D =
    Product{D}(f, params)

Product{D}(params::Union{AbstractRange,AbstractArray}...) where D =
    Product{D}(nothing, params)

Base.eltype(p::Product{D}) where D = D
# corregir, ahora que P es NTuple:
# # need to know how many arguments p.f (p::Product) takes:
# Base.length(::Type{NTuple{N,T}}) where {N,T} = N
# Base.length(p::Product) = length(p.params)
# Base.ndims(p::Product) = ndims(p.params)
# function Base.iterate(d::Product{D,P}, i=1) where {D,P<:AbstractArray}
#     i-1 < length(d.params) ? (D(d.f(d.params[i]...)...), i+1) : nothing
# end
# function Base.iterate(d::Product{D,P}, args...) where {D,P<:ProductIterator}


Distributions.params(d::Product) = d.params

@inline function logpdf(p::Product, xs::AbstractArray) # D<:Sampleable{X}
    sum(logpdf(eltype(p)).(p.f.(p.params...), xs))
end

@inline function logpdf(p::Product{D,Nothing}, xs::AbstractArray) where D
    sum(logpdf(D).(p.params..., xs))
end

function Base.rand(p::Product{D}) where D
    map(p.f.(p.params...)) do θ
        (rand ∘ D)(θ...)
    end
end


##############
# utils
##############

### Based on Michael Abbott's `outer` in NamedPlus, which as things stand cannot be added because of compatibility restrictions:
const newaxis = [CartesianIndex()]

function ngrid(xs...)
    dims = 0
    views = map(xs) do x
        newaxes = ntuple(_->newaxis, dims)
        colons = ntuple(_->(:), ndims(x))
        dims += ndims(x)
        view(x, newaxes..., colons...)
    end
end

outer(f::Function, xs::AbstractArray...) = Broadcast.broadcast(f, ngrid(xs...)...)

Base.:(*)(s::Tuple, t::Tuple) = (s..., t...)

Core.nothing(x...) = x


#############
# For
#############
# using MLStyle
#
# macro deconstruct(f::Expr)
#     @match f begin
#         Expr(:->, η, Expr(:block, _, Expr(:call, d, θ...))) =>
#             (eval(d), eval(Expr(:->, η, Expr(:tuple, θ...))))
#         _ => error("could not deconstruct lambda expression")
#     end
# end

# # esta opcion es bonita:
# @product for θ in θs
#     Normal(θ...)
# end

For(f, t::Union{Integer,AbstractRange,AbstractArray}...; D) = For(f, t; D=D)

function For(f, θs::T; D) where
         {N, J<:Union{AbstractRange,AbstractArray}, T<:NTuple{N,J}}
    θgrid = ngrid(θs...)
    Product{D}(f, θgrid)
end

For(f, dims::T; D) where {N, J<:Integer, T<:NTuple{N,J}} =
    For(f, map(n -> 1:n, dims); D=D)

# fallback to arrays, assuming T is collectable
For(f, θs...; D) = For(f, collect.(θs)...; D=D)


# T <: Base.Generator
# function For(f::F, θ::T) where {F, T <: Base.Generator}
#     d = f(θ.f(θ.iter[1]))
#     D = typeof(d)
#     X = eltype(d)
#     For{F, T, D, X}(f,θ)
# end
#
#


##############
# iid
##############

iid(dims::Int...) = dist -> iid(dist, dims...)


function iid(dist, dims::Int...)
    f = (_...) -> params(dist)
    θgrid = ngrid(map(n -> 1:n, dims)...)
    Product{typeof(dist)}(f, θgrid)
end

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
