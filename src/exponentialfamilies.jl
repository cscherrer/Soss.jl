# module ExponentialFamilies
using Distributions


# A parameterized exponential family
struct ExponentialFamily{P,X} 
    logh :: Function # :: X -> Real
    logg :: Function # :: P -> Real
    η    :: Function # :: P -> StaticVector{N, Real}
    t    :: Function # :: X -> StaticVector{N, Real}
end

# A specific instance of a distribution belonging to an exponential family
struct ExpFamDist{P,X}
    fam :: ExponentialFamily{P,X}
    θ :: P
end

# Find the exponential family distribution instance for a given distribution.
# This needs to be reworked, since many distributions are not from exponential families
efam(d::ExpFamDist{P,X} where {P,X}) = d

Distributions.logpdf(d::ExpFamDist{P,X}, x :: X) where {P,X} = d.fam.logh(x) + d.fam.logg(d.θ) + sum(d.fam.η(d.θ) .* d.fam.t(x))

# Exponential families are closed under iid
function iid(n::Integer, d::ExpFamDist{P,X} ) where {P,X}
    fam = d.fam
    logh(xs) = sum(fam.logh.(xs))
    logg(θ) = n * fam.logg(θ)
    η(θ) = fam.η(θ)
    t(xs) = sum(fam.t.(xs))

    newfam = ExponentialFamily{P,Vector{X}}(logh, logg, η, t)
    ExpFamDist{P,Vector{X}}(newfam,d.θ)
end

iid(n, d ) = iid(n,efam(d))

################################
# Bernoulli example


logit(p) = log(p/(1-p))

function efam(d::Bernoulli{P}) where {P <: Real}
    logh(x) = 0
    logg(p::P) = -log(1 - p)
    η(p::P) = logit(p)
    t(x) = Float64(x)

    fam = ExponentialFamily{P,Bool}(logh, logg, η, t)
    
    ExpFamDist(fam, d.p)
end




efam(Bernoulli(0.2))



binom = iid(1000,Bernoulli(0.2))

using BenchmarkTools

@btime logpdf(binom, repeat([true],1000))

@btime sum(logpdf.(Bernoulli(0.2),repeat([true],1000)))

################################
# Normal example

const sqrt2π = sqrt(2*π)

const invsqrt2π = 1/sqrt(2*π)

function efam(d::Normal{P}) where {P <: Real}
    logh(x) = invsqrt2π
    logg(θ) = 0.5 * (θ.μ/θ.σ)^2 + log(θ.σ)
    η(θ) = (θ.μ/θ.σ^2, -1/(2*θ.σ^2))
    t(x) = (x,x^2)

    fam = ExponentialFamily{NamedTuple{(:μ, :σ),Tuple{P,P}}, Float64}(logh, logg, η, t)
    
    ExpFamDist(fam, (μ=d.μ,σ=d.σ))
end

const xs = 3 .+ 4 .* randn(1000);

@btime logpdf(iid(1000,Normal(3.1,4.3)), xs)

@btime sum(logpdf.(Normal(3,4),xs))



# end # module
