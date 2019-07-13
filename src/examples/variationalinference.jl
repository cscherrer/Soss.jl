using Pkg
Pkg.activate(".")
using Revise
using Soss
using BenchmarkTools
using Traceur
using MonteCarloMeasurements

p = @model x,N begin
    μ ~ Cauchy(0, 1)
    σ ~ HalfCauchy(3)
    x ~ For(1:N) do n
            Normal(μ + n, σ)
        end
end
    
q = @model (μm,μs,logσm, logσs) begin
    μ ~ Normal(μm, μs)
    logσ ~ Normal(logσm, logσs)
    σ = exp(logσ)
end

groundTruth = rand(p; N=10)

sourceParticleImportance(p,q)


g = sourceParticleImportance(p,q) |> eval

g(100, merge(groundTruth,(μm=1.0,μs=1.0,logσm=1.0, logσs=1.0)))

xs = rand(Normal(0,1),100)
ys = rand(Normal(-14,1),100)
zs = g.(xs,ys)
s = sortperm(zs,rev=true)
xs[s]
ys[s]

