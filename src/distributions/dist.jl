export LogisticBinomial, HalfCauchy, HalfNormal, EqualMix, StudentT
import Distributions.logpdf
# using SymPy

logdensity(dist::Distributions.Distribution, x) = logpdf(dist,x)

struct HalfCauchy{T<:Real} <: Distribution{Univariate,Continuous}
    σ::T
end

HalfCauchy(σ::Integer = 1) = HalfCauchy(float(σ))

logdensity(d::HalfCauchy, x::Real) = log(2) + logdensity(Cauchy(0, d.σ), x)

Base.rand(rng::AbstractRNG, d::HalfCauchy) = abs(rand(rng, Cauchy(0, d.σ)))


struct HalfNormal{T<:Real} <: Distribution{Univariate,Continuous}
    σ::T
end

HalfNormal(σ::Integer = 1) = HalfNormal(float(σ))

logdensity(d::HalfNormal, x::Real) = log(2) + logdensity(Normal(0, d.σ), x)

Base.rand(rng::AbstractRNG, d::HalfNormal) = abs(rand(rng, Normal(0, d.σ)))

# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n, x) = Binomial(n, logistic(x))


struct EqualMix{T}
    components::Vector{T}
end

logdensity(m::EqualMix, x) = logsumexp(map(d -> logdensity(d, x), m.components))

Base.rand(rng::AbstractRNG, m::EqualMix) = rand(rng, rand(rng, m.components))

xform(d::EqualMix, _data) = xform(d.components[1], _data)


StudentT(ν, μ = 0.0, σ = 1.0) = LocationScale(μ, σ, TDist(ν))


xform(d::Dirichlet, _data) = UnitSimplex(length(d.alpha))
