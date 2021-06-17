

using Soss
using MeasureTheory

m = @model n begin
    α ~ Normal()
    β ~ Normal()
    x ~ Normal() |> iid(n)
    σ ~ Exponential(λ=1)
    y ~ For(x) do xj
        Normal(α + β * xj, σ)
    end
    return y
end

rand(m(3))
rand(m(3),5)
simulate(m(3), 5)
mysim = simulate(m(3), 1000)
mysim[1]

mytrace = mysim.trace

using TupleVectors
@with mytrace begin
        ŷ = α .+ β .* x
        r = y - ŷ
        (;ŷ, r)
end 