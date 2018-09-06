using Distributions
import Base.rand
export iid

struct iid
    n
    dist
end

iid(n) = dist -> iid(n,dist)

rand(ndist::iid) = rand(ndist.dist, ndist.n)




