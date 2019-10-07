using Distributions
import Distributions.logpdf
using Parameters

# D is type type of the base distribution
# T is the type of Parameters
# X is the type of observations
export For
struct For # <: Distribution{Multivariate,S} where {T, X, D <: Distribution{V,X} where V <: VariateForm, S <: ValueSupport} # where {A, D <: Distribution{V,A} where V, T, X} 
    f   # f(θ) returns a distribution of type D
    θs 
end

For(f, θs::AbstractRange...) = For(f,θs)

# function For(f, θs) 
#     T = eltype(θs)
#     d = f(θs[1])
#     D = typeof(d)
#     X = eltype(d)
#     For(f,θs)
# end

export rand

Base.rand(dist::For) = map(rand, map(ci -> dist.f(Tuple(ci)...),CartesianIndices(dist.θs)))

# Distributions.logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.θs), xs) |> sum



# @inline function Distributions.logpdf(d::For,xs::AbstractArray)
#     f = d.f
#     θs = CartesianIndices(d.θs)

#     s = 0.0
#     # for (θ,x) in zip(θs, xs)
#     @simd for I in CartesianIndices(d.θs)
#         @inbounds s += logpdf(f(Tuple(I)...), xs[I])
#     end
#     s
# end

# arrayRank(::Type{Array{T,N}}) where {T,N} = N

using Base.Cartesian



@generated function Distributions.logpdf(d::For,x::AbstractArray{T,N}) where {T,N}
    # N = arrayRank(x)
    ituple = @macroexpand @ntuple($N, i)
    quote
        s = 0.0
        @nloops $N i x begin
            s += logpdf(@ncall($N,d.f,i->(@ntuple $N i)), @nref $N x i)
        end
        s
    end
end

export lpdf
@inline function lpdf(d::For,xs::AbstractArray)
    f = d.f
    θs = CartesianIndices(d.θs)

    s = 0.0
    for (θ,x) in zip(θs, xs)
        s += logpdf(f(Tuple(θ)...), x)
    end
    s
end

# function For(f, js; dist=nothing)
#     @match dist begin
#         fam::ExponentialFamily => ForEF(f, js, fam)
#         x => For(f, js)
#     end
# end
using Transducers
using Transducers: @next, complete
function Transducers.__foldl__(rf, val, d::For)
    for θ in d.θs
        val = @next(rf, val, f(θ))
    end
    return complete(rf, val)
end
