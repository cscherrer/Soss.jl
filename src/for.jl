using Distributions
import Distributions.logpdf

export For
struct For{F,T,D,X} 
    f :: F  
    θ :: T
end

#########################################################
# T <: Integer
#########################################################

For(f::F, θ::T) where {F, T <: Integer}

#########################################################
# T <: NTuple{N,J} where {J <: Integer}
#########################################################

For(f, θ::J...) where {J <: Integer} = For(f,θ)
For(f::F, θ::T) where {F, T <: NTuple{N,J}, J <: Integer}


#########################################################
# T <: NTuple{N,J} where {J <: AbstractUnitRange}
#########################################################

For(f, θ::J...) where {J <: AbstractUnitRange} = For(f,θ)
For(f::F, θ::T) where {F,  T <: NTuple{N,J}, J <: AbstractUnitRange}


#########################################################
# T <: Base.Generator
#########################################################

For(f::F, θ::T) where {F, T <: Base.Generator}

#########################################################



For(f, θ::Int...) = For(f,θ)

# T <: Integer

# T <: 

function For(f::F, θ::NTuple{N}) where {F,N}
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
using Base.Threads

export logpdf

@inline function logpdf(d::For{F,N,X1},xs::AbstractArray{X2,N}) where {F,N, X1,  X2 <: X1}
    s = 0.0
    @inbounds @simd for θ in CartesianIndices(d.θ)
        s += logpdf(d.f(Tuple(θ)...), xs[θ])
    end
    s
end

export logpdf2
@inline function logpdf2(d::For{F,N,X1},xs) where {F,N, X1, X2}
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

