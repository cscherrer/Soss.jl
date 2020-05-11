struct AbstractSimplex{T} end

export Simplex
struct Simplex{T}  <: AbstractVector{T}
    weights::Vector{T}
end

function Simplex(w) 
    N = length(w)
    T = eltype(w)
    Simplex{T}(w)
end

Base.length(s::Simplex{T}) where {T} = length(s.weights)
Base.size(s::Simplex{T}) where {T} = (length(s.weights),)
Base.getindex(s::Simplex{T}, n) where {T} = s.weights[n]


struct Log{T}
    val :: T
end

function Base.:*(x::Log{Tx}, y::Log{Ty}) where {Tx <: Real, Ty <: Real}  
    Log(x.val + y.val)
end

Base.log(x::Log{T}) where {T <: Real} = x.val


struct AbstractMix end

struct MixFor
    dists :: For
    weights :: Simplex
end

struct MixVec{D,W}
    dists :: Vector{D}
    weights :: Simplex{W}
end



export Mix

function Mix(dists :: Vector{D}, weights :: Vector{W}) where {D,W}
    MixVec{D,W}(dists, Simplex(weights))
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

function logdensity(mix::MixVec, x)
    ℓ = 0.0
    @simd for j in eachindex(mix.weights)
        @inbounds ℓ += log(mix.weights[j]) + logdensity(mix.dists[j], x)
    end
    ℓ
end
