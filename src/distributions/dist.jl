export LogisticBinomial, HalfCauchy, HalfNormal, EqualMix, StudentT
import Distributions.logdensity

struct HalfCauchy{T<:Real} <: Distribution{Univariate,Continuous}
    σ::T
end

HalfCauchy(σ::Integer = 1) = HalfCauchy(float(σ))

Dists.params(d::HalfCauchy) = (d.σ,)

Distributions.logdensity(d::HalfCauchy, x::Real) = log(2) + logdensity(Cauchy(0, d.σ), x)

Dists.pdf(d::HalfCauchy, x) = 2 * pdf(Cauchy(0, d.σ), x)

Base.rand(rng::AbstractRNG, d::HalfCauchy) = abs(rand(rng, Cauchy(0, d.σ)))

Dists.quantile(d::HalfCauchy, p) = quantile(Cauchy(0, d.σ), (p + 1) / 2)

Dists.support(::HalfCauchy) = RealInterval(0.0, Inf)


struct HalfNormal{T<:Real} <: Distribution{Univariate,Continuous}
    σ::T
end

HalfNormal(σ::Integer = 1) = HalfNormal(float(σ))

Dists.params(d::HalfNormal) = (d.σ,)

Distributions.logdensity(d::HalfNormal, x::Real) = log(2) + logdensity(Normal(0, d.σ), x)

Dists.pdf(d::HalfNormal, x) = 2 * pdf(Normal(0, d.σ), x)

Base.rand(rng::AbstractRNG, d::HalfNormal) = abs(rand(rng, Normal(0, d.σ)))

Dists.quantile(d::HalfNormal, p) = quantile(Normal(0, d.σ), (p + 1) / 2)

Dists.support(::HalfNormal) = RealInterval(0.0, Inf)


# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n, x) = Binomial(n, logistic(x))


struct EqualMix{T}
    components::Vector{T}
end

Distributions.logdensity(m::EqualMix, x) = logsumexp(map(d -> logdensity(d, x), m.components))

rand(m::EqualMix) = rand(GLOBAL_RNG, m)

Base.rand(rng::AbstractRNG, m::EqualMix) = rand(rng, rand(rng, m.components))

xform(d::EqualMix, _data) = xform(d.components[1], _data)


# StudentT(ν, μ = 0.0, σ = 1.0) = LocationScale(μ, σ, TDist(ν))


xform(d::Dists.Dirichlet, _data) = UnitSimplex(length(d.alpha))
