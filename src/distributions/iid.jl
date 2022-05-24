export iid


iid(n::Integer...) = dist -> iid(dist, n...)

iid(dist, n...) = dist ^ n

iid(dist::Dists.Distribution, n...) = MeasureBase.powermeasure(dist, n)
