using Distributions
import Distributions.logpdf
using Parameters

export For
struct For{D,T,X}
    f # returns a distribution of type D
    θs :: Array{T}
end

function For(f, θs) 
    T = eltype(θs)
    d = f(θs[1])
    D = typeof(d)
    X = eltype(d)
    For{D,T,X}(f,θs)
end

export rand

Base.rand(dist::For{D,T,X} where {D,T,X}) = map(rand, map(dist.f,dist.θs))

# Distributions.logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.θs), xs) |> sum



@inline function Distributions.logpdf(d::For{D,T,X},x::Array{X}) where {D,T,X}
    @unpack (f,θs) = d

    s = 0.0
    @inbounds @simd for j in eachindex(x)
        θ = θs[j]::T 
        logpdf(f(θ)::D, x[j]::X)
    end
    s
end



# function For(f, js; dist=nothing)
#     @match dist begin
#         fam::ExponentialFamily => ForEF(f, js, fam)
#         x => For(f, js)
#     end
# end
