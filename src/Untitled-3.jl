using Distributions
using Plots
using BenchmarkTools

function f(μ)
    n = 0
    Σx = 0
    tn = 0
    while tn < 10
        Σx += rand(Normal(μ,1))
        n += 1
        tn = Σx/n * sqrt(n)
    end
    return n 
end





θs = 10 .^ range(-2,1,length=200)
scatter(θs, f.(θs), scale=:log10)