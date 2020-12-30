export Flat

struct Flat
end

Distributions.logpdf(::Flat, x) = 0.0

struct HalfFlat
end

Distributions.logpdf(::HalfFlat, x) = 0.0
