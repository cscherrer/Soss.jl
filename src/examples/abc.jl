
δ(θ) = abs(θ.x-0.5) < 0.01


sim(μ) = rand(Normal(μ,1))

m = @model x,sim begin
    μ ~ Cauchy()
    x ~ Simulation(sim, μ)
end

f = abc(m,δ;sim=sim)
f()