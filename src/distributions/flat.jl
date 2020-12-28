export Flat

struct Flat
end

Distributions.logdensity(::Flat, x) = 0.0

struct HalfFlat
end

Distributions.logdensity(::HalfFlat, x) = 0.0
