export LogisticBinomial, HalfCauchy, HalfNormal
import Distributions.logpdf
using SymPy

struct HalfCauchy
    scale
end

HalfCauchy() = HalfCauchy(1)

Distributions.logpdf(d::HalfCauchy,x) = log(2) + logpdf(Cauchy(0,d.scale),x)

Distributions.pdf(d::HalfCauchy,x) = 2 * pdf(Cauchy(0,d.scale),x)

Distributions.rand(d::HalfCauchy) = abs(rand(Cauchy(0,d.scale)))

Distributions.quantile(d::HalfCauchy, p) = quantile(Cauchy(0, d.scale), (p+1)/2)

struct HalfNormal
    scale
end

HalfNormal() = HalfNormal(1)


Distributions.logpdf(d::HalfNormal,x) = log(Sym(2)) + logpdf(Normal(0,d.scale),x)

Distributions.pdf(d::HalfNormal,x) = 2 * pdf(Normal(0,d.scale),x)

Distributions.rand(d::HalfNormal) = abs(rand(Normal(0,d.scale)))


# HalfNormal(s) = Truncated(Normal(0,s),0,Inf)
# HalfNormal() = Truncated(Normal(0,1.0),0,Inf)


# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n,x)=Binomial(n,logistic(x))
