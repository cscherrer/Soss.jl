using Distributions
import Distributions.logpdf

export For
struct For
    f
    xs
end

export rand

Distributions.rand(dist::For) = map(rand, map(dist.f,dist.xs))

Distributions.logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.xs), xs) |> sum

