export Weighted
struct Weighted{W,T}
    ℓ :: W
    val :: T
end

using Printf
function Base.show(io::IO, ℓx::Weighted)
    @printf io "Weighted(%g.4" (ℓx.ℓ)
    println(",", ℓx.val)
end