using MeasureTheory
using Base.Iterators
using Statistics

using Random
rng = Random.Xoshiro(3)

x = Chain(Normal()) do xj Normal(μ=xj) end
xobs = rand(rng, x)
y = For(xobs) do xj Poisson(logλ=xj) end
yobs = rand(rng, y)
xv = take(xobs, 10) |> collect
yv = take(yobs, 10) |> collect

take(xobs.parent, 10) |> collect
take(yobs.parent, 10) |> collect


exp.(xv)
yv

# using Plots

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

logdensity(m(), (x=xobs, y=yobs))

