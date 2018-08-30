using Distributions
import Distributions.logpdf
import Base.rand

struct For
    f
    xs
end

rand(ex::For) = map(rand, map(ex.f,ex.xs))
