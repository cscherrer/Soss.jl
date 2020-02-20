using CUDAnative
# using Distributions
# using Distributions: zval, log2π

Base.@irrational log2π  1.8378770664093454836 log(big(2.)*π)
Base.@irrational sqrt2π 2.5066282746310005024 sqrt(big(π)*2.0)
# Base.@irrational invsqrt2π 0.3989422804014326779 inv(big(sqrt2π))


zval(μ::Real, σ::Real, x::Number) = (x - μ) / σ

# # pdf
# cunormpdf(z::Number) = CUDAnative.exp(-CUDAnative.abs2(z)/2) * invsqrt2π
# function cunormpdf(μ::Real, σ::Real, x::Number)
#     if iszero(σ)
#         if x == μ
#             z = zval(μ, one(σ), x)
#         else
#             z = zval(μ, σ, x)
#             σ = one(σ)
#         end
#     else
#         z = zval(μ, σ, x)
#     end
#     cunormpdf(z) / σ
# end

# logpdf
cunormlogpdf(x::Real) = -(x^2 + log2π)/2

function cunormlogpdf(p::Tuple{Real,Real}, x::Real)
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
    cunormlogpdf(z) - CUDAnative.log(σ)
end
