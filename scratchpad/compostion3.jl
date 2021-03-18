using Soss

μdist = @model begin
    a ~ Normal()
    b ~ Normal()
    return a/b
end

σdist = @model begin
    x ~ Normal()
    return x^2
end

m = @model begin
    μ ~ μdist()
    σ ~ σdist()
    x ~ Normal(μ,σ) |> iid(2)
    return x
end

rand(m(),5)

simulate(m(), 5)

dynamicHMC(m() | (x = randn(2),))
