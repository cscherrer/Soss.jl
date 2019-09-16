export LogisticBinomial, HalfCauchy, HalfNormal
import Distributions.logpdf
# using SymPy

struct HalfCauchy{T} <: Distribution{Univariate,Continuous}
    σ::T

    function HalfCauchy{T}(σ::T) where T
        new{T}(σ)
    end
end

HalfCauchy(σ::T) where {T<:Real} = HalfCauchy{T}(σ)
HalfCauchy(σ::Integer) = HalfCauchy(Float64(σ))
HalfCauchy() = HalfCauchy(1.0)

Distributions.logpdf(d::HalfCauchy{T} ,x::Real) where {T}  = log(2.0) + logpdf(Cauchy(0.0,d.σ),x)

Distributions.pdf(d::HalfCauchy,x) = 2 * pdf(Cauchy(0,d.σ),x)

Distributions.rand(d::HalfCauchy) = abs(rand(Cauchy(0,d.σ)))

Distributions.quantile(d::HalfCauchy, p) = quantile(Cauchy(0, d.σ), (p+1)/2)

Distributions.support(::HalfCauchy{T} where T) = RealInterval(0.0, Inf)

struct HalfNormal
    σ
end

HalfNormal() = HalfNormal(1)


Distributions.logpdf(d::HalfNormal,x::Real) = log(2) + logpdf(Normal(0,d.σ),x)

Distributions.pdf(d::HalfNormal,x) = 2 * pdf(Normal(0,d.σ),x)

Distributions.rand(d::HalfNormal) = abs(rand(Normal(0,d.σ)))

Distributions.support(::HalfNormal) = RealInterval(0.0, Inf)

# HalfNormal(s) = Truncated(Normal(0,s),0,Inf)
# HalfNormal() = Truncated(Normal(0,1.0),0,Inf)


# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n,x)=Binomial(n,logistic(x))

struct EqualMix{T}
    components::Vector{T}
end

function Distributions.logpdf(m::EqualMix{T}, x) where {T}
    logsumexp(map(d -> logpdf(d,x), m.components))
end

function Base.rand(m::EqualMix{T}) where {T}
    map(rand, m.components)
end