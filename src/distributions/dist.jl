as(d::EqualMix, _data) = as(d.components[1], _data)


# StudentT(ν, μ = 0.0, σ = 1.0) = LocationScale(μ, σ, TDist(ν))


as(d::Dists.Dirichlet, _data) = UnitSimplex(length(d.alpha))
