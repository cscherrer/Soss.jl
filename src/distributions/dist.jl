xform(d::EqualMix, _data) = xform(d.components[1], _data)


# StudentT(ν, μ = 0.0, σ = 1.0) = LocationScale(μ, σ, TDist(ν))


xform(d::Dists.Dirichlet, _data) = UnitSimplex(length(d.alpha))
