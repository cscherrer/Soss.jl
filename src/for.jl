using Distributions
import Distributions.logpdf

export For
struct For
    f
    xs
end

export rand

rand(dist::For) = map(rand, map(dist.f,dist.xs))

logpdf(dist::For, xs) = logpdf.(map(dist.f, dist.xs), xs) |> sum