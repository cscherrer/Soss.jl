using Distributions
import Distributions.logpdf
using Parameters

# D is type type of the base distribution
# T is the type of Parameters
# X is the type of observations
export For
struct For{N,F} # <: Distribution{Multivariate,S} where {T, X, D <: Distribution{V,X} where V <: VariateForm, S <: ValueSupport} # where {A, D <: Distribution{V,A} where V, T, X} 
    f :: F  # f(θ) returns a distribution of type D
    θs :: NTuple{N, UnitRange{Int}}
end

function For(f, θs::UnitRange{Int}...)
    For{length(θs), typeof(f)}(f,θs)
end

# function For(f, θs) 
#     T = eltype(θs)
#     d = f(θs[1])
#     D = typeof(d)
#     X = eltype(d)
#     For(f,θs)
# end

export rand

function Base.rand(dist::For)
    map(CartesianIndices(dist.θs)) do I
        (rand ∘ dist.f)(Tuple(I)...)
    end
end

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

@generated function lpdf(d::For{N},x::Array{T,N}) where {T,N}
    ixs = Symbol.("i_",1:N) |> Tuple  # (:i_1, :i_2, :i_3)
    ixs_tuple = Expr(:tuple, ixs...)  # :((i_1, i_2, i_3))

    # @gensym s
    s = :s
    q = @q begin
        @inbounds θ = getindex.(d.θs, $ixs_tuple)
        @inbounds $s += logpdf(d.f(θ...), x[$ixs_tuple...])
        # @show $s
    end

    for loopnum in 1:N
        q = @q begin
            @inbounds @simd for $(ixs[loopnum]) in d.θs[$loopnum]
                $q
            end
        end
    end

    
    q = (@q begin
        $s = 0.0
        $q
        $s
    end) |> flatten


end


# @generated function Distributions.logpdf(d::For,x::AbstractArray{T,N}) where {T,N}
#     # N = arrayRank(x)
#     ituple = @macroexpand @ntuple($N, i)
#     quote
#         s = 0.0
#         @nloops $N i x begin
#             s += logpdf(@ncall($N,d.f,i->(@ntuple $N i)), @nref $N x i)
#         end
#         s
#     end
# end

export logpdf
@inline function logpdf(d::For,xs::AbstractArray)
    s = 0.0
    for (θ,x) in zip(CartesianIndices(d.θs), xs)
        s += logpdf(d.f(Tuple(θ)...), x)
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
