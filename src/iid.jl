using Distributions
import Distributions.logpdf

# TODO: iid is currently a bit weird. We'd like it to allow both a specific multiplicity and "on demand" (unspecified but flexible). It's clear how to do either, but not yet if this will allow a single representation.

export iid
struct iid
    size
    dist
end

# TODO: Clean up this hack
iid(n::Int) = dist -> iid(n,dist)

iid(dist) = iid(Nothing, dist)

function Base.iterate(d::iid)
    n = prod(d.size) * length(d.dist)
    return (d.dist, (n, 1))
end

function Base.iterate(d::iid, state)
    (n, count) = state
    count < n && return (d.dist, (n, count + 1))
    return nothing
end

# Distributions.cdf(iid, x) = cdf.(iid.dist, x)
# Distributions.quantile(iid, x) = quantile.(iid.dist, x)

import Base.length
Base.length(d::iid) = prod(d.size)

import Base.eltype
Base.eltype(d::iid) = typeof(d.dist)

rand(d::iid) = rand(d.dist,d.size)

function Distributions.logpdf(d::iid,x)
    s = Float64(0)
    Δs(xj) = logpdf(d.dist, xj)
    @inbounds @simd for j = 1:length(x)
        s += Δs(x[j])
    end
    s
end
