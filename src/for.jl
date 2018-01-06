using Distributions
import Distributions.logpdf
import Distributions.rand
logpdf{D<:Any, T <: Any, N<:Any}(ds :: AbstractArray{D, N},xs::AbstractArray{T, N}) = sum(logpdf(dx...) for dx in zip(ds,xs))
rand(ds :: AbstractArray{D, N} where {D,N}) = [rand(d) for d in ds]

# THIS IS A HACK
# `For` should really be a constructor. 
# The problem with the current approach is that for a distribution d, `For(1:3) do x d end` has the type of an Array, not a Distribution.
# But this was quick, and it works, so here it is

For = map