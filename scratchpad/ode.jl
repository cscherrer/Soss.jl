using Soss, DifferentialEquations 
using Plots, StatsPlots

function lotka_volterra(du,u,p,t)
  x, y = u
  α, β, γ, δ  = p
  du[1] = (α - β*y)x # dx =
  du[2] = (δ*x - γ)y # dy = 
end
p = [1.5, 1.0, 3.0, 1.0]
u0 = [1.0,1.0]
prob1 = ODEProblem(lotka_volterra,u0,(0.0,10.0),p)


sol1 = solve(prob1,Tsit5(),saveat=0.1)
odedata = rand(For(Poisson, Array(sol1)))

plot(sol1, legend = false); scatter!(sol1.t, odedata')


m = @model ode begin
    α ~ Uniform()
    β ~ Uniform()
    γ ~ Uniform()
    δ ~ Uniform()

    # p = [2α+0.5,2β,3γ+1,2δ]
    p = [20α+0.5,20β,30γ+1,20δ]
    prob = remake(ode, p=p)
    predicted = solve(prob,Tsit5(),saveat=0.1)
        
    data ~ For(Array(predicted)) do λ Poisson(λ) end
end

post = dynamicHMC(m(ode=prob1) | (data=odedata,))

plt = plot(sol1, legend = false)

for x in post
    p = [2 * x.α + 0.5,2 * x.β,3 * x.γ + 1,2 * x.δ]

    thisprob = remake(prob1, p=p)
    thissol = solve(thisprob,Tsit5(),saveat=0.1)
    plot!(plt, thissol, alpha=0.02, linewidth=2, color = :black, legend = false)
end
# display(pl)
plot!(sol1, w=1, legend = false)
scatter!(sol1.t, odedata')
