using Pkg
Pkg.activate(".")
using Revise
using Soss

δ(θ) = abs(θ.x-0.5) < 0.01


sim(μ) = rand(Normal(μ,1))

m = @model x,sim begin
    μ ~ Cauchy()
    x ~ Simulation(sim, μ)
end

f = abc(m,δ;sim=sim)
post = [f().μ for j in 1:2000];

Particles(post)