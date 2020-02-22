using Distributions
import Distributions.logpdf

# TODO: iid is currently a bit weird. We'd like it to allow both a specific multiplicity and "on demand" (unspecified but flexible). It's clear how to do either, but not yet if this will allow a single representation.

export iid
struct iid{X,N,D}
    size :: NTuple{N,Int}
    dist :: D
    iid(d::D, s::Int...) where D<:Sampleable =
        new{eltype(d),length(s),typeof(d)}(s, d)
end


iid(t::Int...) = dist -> iid(dist, t...)
# iid(dist) = iid(Nothing, dist)

# Distributions.cdf(iid, x) = cdf.(iid.dist, x)
# Distributions.quantile(iid, x) = quantile.(iid.dist, x)

Distributions.params(d::iid) = [params(d.dist)]

function Base.iterate(d::iid,
                      state = (prod(d.size) * length(d.dist), 0))
    (n, count) = state
    count < n && return (d.dist, (n, count + 1))
    return nothing
end

Base.length(d::iid) = prod(d.size)
Base.eltype(::iid{X,N,D}) where {X,N,D} = D
# elkind(::iid{X,N,D}) where {X,N,D} = Base.typename(D).wrapper

function Base.rand(d::iid{X}) where X
    x = Array{X}(undef, d.size)
    for cartix in CartesianIndices(x)
        ix = Tuple(cartix)
        @inbounds setindex!(x, rand(d.dist), ix...)
    end
    x
end

# function Distributions.logpdf(d::iid, x)
#     s = zero(Float64)
#     Δs(xj) = logpdf(d.dist, xj)
#     @inbounds @simd for j in eachindex(x)
#         s += Δs(x[j])
#     end
#     s
# end

# # Already defined in for.jl (this needs refactoring)
# function Distributions.logpdf(d::iid{X,N}, xs::CuArray{X,N}) where {X,N}
#     sum(logpdf(eltype(d)).(CuArray(params(d)), xs))
# end


# function Base.rand(d::Union{iid, HalfNormal}, n::Int)
#     x1 = rand(d)
#     x = Array{typeof(x1),1}(undef, n)
#     for j in eachindex(x)
#         @inbounds x[j] = rand(d)
#     end
#     x
# end
