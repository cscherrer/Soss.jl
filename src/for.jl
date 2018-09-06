using Distributions
import Distributions.logpdf
import Base.rand

struct For
    f
    xs
end

rand(dist::For) = map(rand, map(dist.f,dist.xs))

logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.xs), xs) |> sum