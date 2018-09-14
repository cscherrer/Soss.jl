export LogisticBinomial, HalfCauchy

HalfCauchy(s) = Truncated(Cauchy(0,s),0,Inf)

import Distributions.support
export support
support(::typeof(HalfCauchy)) = RealInterval(0, Inf)


# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n,x)=Binomial(n,logistic(x))
