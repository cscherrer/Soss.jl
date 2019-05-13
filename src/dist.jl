export LogisticBinomial, HalfCauchy, HalfNormal

HalfCauchy(s) = Truncated(Cauchy(0,s),0,Inf)
HalfCauchy() = Truncated(Cauchy(0,1.0),0,Inf)

HalfNormal(s) = Truncated(Normal(0,s),0,Inf)
HalfNormal() = Truncated(Normal(0,1.0),0,Inf)


# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n,x)=Binomial(n,logistic(x))
