using CUDAnative
using Distributions: log2π
using CuArrays: @cufunc
import StatsFuns: normlogpdf, gammalogpdf
using StaticArrays


# Base.@irrational log2π  1.8378770664093454836 log(big(2.)*π)
# Base.@irrational sqrt2π 2.5066282746310005024 sqrt(big(π)*2.0)
# Base.@irrational invsqrt2π 0.3989422804014326779 inv(big(sqrt2π))

# Categorical
catlogpdf(p::Tuple{SVector{N,T}}, x::Integer) where {N,T<:Real} =
    1 ≤ x ≤ N ? @inbounds(log(p[1][x])) : -T(Inf)
@cufunc catlogpdf(p::Tuple{SVector{N,T}} where N, x::Integer) where T<:Real =
    ifelse(1 ≤ x ≤ length(p[1]), @inbounds(CUDAnative.log(p[1][x])), -T(Inf))

# Uniform:
unilogpdf(p::Tuple{T,T}, x::T) where T<:Real =
    p[1] ≤ x ≤ p[2] ? -log(p[2] - p[1]) : -T(Inf)
@cufunc unilogpdf(p::Tuple{T,T}, x::T) where T<:Real =
    ifelse(p[1] ≤ x ≤ p[2], -CUDAnative.log(p[2] - p[1]), -T(Inf))

# Normal:
zval(μ::Real, σ::Real, x::Number) = (x - μ) / σ
normlogpdf(p::Tuple{Real,Real}, x::Real) = normlogpdf(p[1], p[2], x)
function _cunormlogpdf(p::Tuple{Real,Real}, x::Real)
    μ, σ = p
    if iszero(σ)
        if x == μ
            z = zval(μ, one(σ), x)
        else
            z = zval(μ, σ, x)
            σ = one(σ)
        end
    else
        z = zval(μ, σ, x)
    end
    -(z^2 + log2π)/2 - CUDAnative.log(σ)
end
@cufunc normlogpdf(p::Tuple{Real,Real}, x::Real) =
    _cunormlogpdf(p::Tuple{Real,Real}, x::Real)


# Gamma:
gammalogpdf(p::Tuple{Real,Real}, x::Real) = gammalogpdf(p[1], p[2], x)
_cugammalogpdf(p::Tuple{Real,Real}, x::Real) =
    -CUDAnative.lgamma(p[1]) - p[1] * CUDAnative.log(p[2]) + (p[1] - 1) * CUDAnative.log(x) - x / p[2]
@cufunc gammalogpdf(p::Tuple{Real,Real}, x::Real) =
    _cugammalogpdf(p::Tuple{Real,Real}, x::Real)


###############
# General stuff, refactor:

# for f in [:normlogpdf, :gammalogpdf]
#     @eval @cufunc $f(p::Tuple{Real,Real}, x::Real) =
#         $(Symbol(:_cu,f))(p::Tuple{Real,Real}, x::Real)
# end


# fallback
logpdf(D) = (θ, x) -> logpdf(D(θ...), x)

# implemented cases
for (D, prefix) in [(:Categorical,:cat),
                    (:Uniform,:uni),
                    (:Normal,:norm),
                    (:Gamma,:gamma)]
    @eval logpdf(::Type{<:$D}) = $(Symbol(prefix, :logpdf))
end
