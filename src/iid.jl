using Distributions
import Distributions.logpdf
export iid

struct iid
    # n :: Int
    dist
end

# iid(n) = dist -> iid(n,dist)


rand(ndist::iid) = rand(ndist.dist, ndist.n)

logpdf(d::iid,x) = sum(logpdf.(d.dist,x))
