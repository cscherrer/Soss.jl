struct ExponentialFamily{P,X,N}
    logh # :: X -> Real
    logg # :: P -> Real
    η    # :: P -> StaticVector{N, Real}
    t    # :: X -> StaticVector{N, Real}
end

struct ExpFamDist{P,X,N}
    fam :: ExponentialFamily{P,X,N}
    θ :: P
end

logpdf(d::ExpFamDist, x) = d.fam.logh(x) + d.fam.logg(d.θ) + d.fam.η(d.θ) * d.fam.t(x)


# function iid(n, d::ExpFamDist) 
#     logh(x) = d.fam.logh.(x) |> sum
#     logg(θ) = d.fam.logg(θ)
#     η(θ)    = d.fam.η(θ) 
#     t(x)    = d.fam.t.(x) |> sum
#     fam = ExponentialFamily(logh, logg, η, t)
#     ExpFamDist(fam, d.θ)
# end

# NormalEF = begin
#     logh(x) = -0.5 * log2π
#     logg(θ) 
#     η(θ) = begin
#         μ = θ[1]
#         σ = θ[2]
#         σinvsq = σ^-2
#         [μ*σinvsq, -0.5 * σinvsq]
#     end
#     t(x) = [x, x^2]
# end


# function ForEF(f, js) 
#     logh(x) = fam.logh.(x) |> sum
#     logg(θ) = fam.logg.(θ) |> sum
#     η(θ)    = fam.η.(θ) 
#     t(x)    = fam.t.(x) 
#     fam = ExponentialFamily(logh, logg, η, t)
#     ExpFamDist(fam, d.θ)
# end