struct AbstractSimplex{N,T} end

export Simplex
struct Simplex{N,T}  <: AbstractVector{T}
    weights::Vector{T}
end

function Simplex(w) 
    N = length(w)
    T = eltype(w)
    Simplex{N,T}(w)
end

Base.length(::Simplex{N,T}) where {N,T} = N
Base.size(::Simplex{N,T}) where {N,T} = (N,)
Base.getindex(s::Simplex{N,T}, n) where {N,T} = s.weights[n]


struct LogFloat{T}
    val
end

function Base.:*(x::LogFloat{Tx}, y::LogFloat{Ty}) where {Tx <: Real, Ty <: Real}  
    LogFloat(x.val + y.val)
end

Base.log(x::LogFloat{T}) where {T <: Real} = x.val


struct AbstractMix end

struct MixFor
    dists :: For
    weights :: Simplex
end

struct MixVec
    dists :: Vector
    weights :: Simplex
end



export Mix

function Mix(dists :: Vector, weights :: Vector)
    MixVec(dists, Simplex(weights))
end

# Mix(w::Vector) = dists -> Mix(dists, log.(w))



function Base.rand(mix::MixVec)
    # This is the "Gumbel max trick"  for categorical sampling
    (j_max,lw_max) = (0,-Inf)

    for j in eachindex(mix.weights)
        lw_gumbel = log(mix.weights[j]) + rand(Gumbel())
        if lw_gumbel > lw_max
            (j_max,lw_max) = (j, lw_gumbel)
        end
    end

    @inbounds mix.dists[j_max] |> rand
end

# function Base.rand(mix::Mix, N::Int)
#     x1 = rand(mix)
#     x = Vector{typeof(x1)}(undef, N)
#     @inbounds x[1] = x1
#     @inbounds for n in 2:N
#         x[n] = rand(mix)
#     end
#     x
# end

xform(mix::MixVec) = xform(mix.dists[1])

function Distributions.logpdf(mix::MixVec, x)
    ℓ = 0.0
    @simd for j in eachindex(mix.weights)
        @inbounds ℓ += log(mix.weights[j]) + logpdf(mix.dists[j], x)
    end
    ℓ
end

