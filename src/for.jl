using Distributions
import Distributions.logpdf
using Parameters

# D is type type of the base distribution
# T is the type of Parameters
# X is the type of observations
export For
struct For # <: Distribution{Multivariate,S} where {T, X, D <: Distribution{V,X} where V <: VariateForm, S <: ValueSupport} # where {A, D <: Distribution{V,A} where V, T, X} 
    f   # f(θ) returns a distribution of type D
    θs :: AbstractArray
end

# function For(f, θs) 
#     T = eltype(θs)
#     d = f(θs[1])
#     D = typeof(d)
#     X = eltype(d)
#     For(f,θs)
# end

export rand

Base.rand(dist::For) = map(rand, map(dist.f,dist.θs))

# Distributions.logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.θs), xs) |> sum



@inline function Distributions.logpdf(d::For,x::AbstractArray)
    f = d.f
    θs = d.θs

    s = 0.0
    @inbounds @simd for j in eachindex(x)
        θ = θs[j]
        s += logpdf(f(θ), x[j])
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
