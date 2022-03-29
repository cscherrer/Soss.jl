using MeasureTheory
using Base.Iterators
using Statistics
using Soss
using Random

# 5 7 10

rng = Random.Xoshiro(12)

m = @model begin
    latent ~ Chain(Normal(μ=1)) do x Normal(μ=x, σ=0.2) end
    observed ~ For(latent) do x Poisson(logλ=x) end
end

truth = rand(rng, m())

xv = take(truth.latent, 100) |> collect
yv = take(truth.observed, 100) |> collect


using Plots

plt = scatter(yv, label="observations")
plot!(exp.(xv), lw=3, label="latent process")

using Statistics

scatter(exp.(xv), poiscdf.(exp.(xv), yv), label=false)

x = Chain(Normal(μ=1)) do xj Normal(μ=xj, σ=0.2) end


xvals = rand(rng, x)
y = For(xobs) do xj Poisson(logλ= xj) end
yvals = rand(rng, y)
xv = take(xobs, 100) |> collect
yv = take(yobs, 100) |> collect

take(xobs.parent, 10) |> collect
take(yobs.parent, 10) |> collect


exp.(xv)
yv


# plt = scatter(normcdf.(xv, 1, yv), label=false)

# for j in 1:10
#     xobs = rand(rng, x)
#     yobs = rand(rng, y)
#     xv = take(xobs, 100) |> collect;
#     yv = take(yobs, 100) |> collect;
#     plt = scatter!(plt, normcdf.(xv, 1, yv), label=false)
# end
# plt

using Soss

m = @model begin
    x ~ Chain(Normal()) do xj Normal(μ=xj) end
    y ~ For(xobs) do xj Poisson(logλ=xj) end
end

truth = rand(rng, m())

xobs = take(truth.x, 10) |> collect
yobs = take(truth.y, 10) |> collect

logdensity_def(m(), (x=xobs, y=yobs))

