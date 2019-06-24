using Distributions
import Distributions.logpdf
using Parameters

export For
struct For{T, D}
    f # returns a distribution of type D
    θs :: Array{T}
end

function For(f, θs) 
    T = eltype(θs)
    D =typeof(f(θs[1]))
    For{T,D}(f,θs)
end

export rand

Base.rand(dist::For{T,D} where {T,D}) = map(rand, map(dist.f,dist.θs))

# Distributions.logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.θs), xs) |> sum



function Distributions.logpdf(d::For{T,D},x) where {T,D}
    f=d.f; θs=d.θs
    
    function Δs(θ, x)
        logpdf(f(θ)::D, x) :: Float64
    end

    s = Float64(0)
    @inbounds @simd for j in eachindex(x)
        s += Δs(θs[j], x[j])::Float64
    end
    s
end



# function For(f, js; dist=nothing)
#     @match dist begin
#         fam::ExponentialFamily => ForEF(f, js, fam)
#         x => For(f, js)
#     end
# end
