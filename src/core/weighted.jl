export Weighted
struct Weighted{W,T}
    ℓ :: W
    val :: T
end

using Printf
function Base.show(io::IO, ℓx::Weighted)
    @printf io "Weighted(%.4g" (ℓx.ℓ)
    println(io, ", ", ℓx.val)
end
