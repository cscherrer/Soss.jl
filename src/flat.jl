export Flat

struct Flat
end

logpdf(::Flat, x) = 0.0

struct HalfFlat
end

logpdf(::HalfFlat, x) = 0.0
