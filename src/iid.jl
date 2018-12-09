using Distributions
import Distributions.logpdf

# TODO: iid is currently a bit weird. We'd like it to allow both a specific multiplicity and "on demand" (unspecified but flexible). It's clear how to do either, but not yet if this will allow a single representation.

export iid
struct iid
    #n :: Int
    dist
end

# iid(n::Int) = dist -> iid(n,dist)

# TODO: Clean up this hack
iid(n::Int) = f -> For(1:n) do x f(x) end


rand(ndist::iid) = rand(ndist.dist, ndist.n)

logpdf(d::iid,x) = sum(logpdf.(d.dist,x))
