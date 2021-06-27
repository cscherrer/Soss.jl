using AbstractGPs, KernelFunctions, Distributions, Soss, LinearAlgebra, Plots, Random

# Adapted from a post by Arthur Lui
# https://discourse.julialang.org/t/gaussian-process-model-with-turing/42453/32?u=cscherrer

# Define model.
m = @model x begin
    # Priors.
    α ~ LogNormal(0.0, 0.1)
    ρ ~ LogNormal(0.0, 1.0)
    σ ~ LogNormal(0.0, 1.0)
    
    # Covariance function.
    kernel = α^2 * transform(SEKernel(), 1/(ρ*√2))

    # GP (implicit zero-mean).
    gp = GP(kernel)
    
    # Sampling Distribution (MvNormal likelihood).
    y ~ gp(x, σ^2 + 1e-6)  # add 1e-6 for numerical stability.
end

Random.seed!(1)
# Get some fake data
x = randn(20)

y =  sinpi.(x) .+ 0.1 .* randn(20);

# Sample from the posterior
post = dynamicHMC(m(x=x), (;y=y))


pred = [posterior(p._y_dist, y) for p in predict(Soss.withdistributions(m)(x=x), post)]


# gps = [posterior(p.gp(x), y) for p in pred]

plt = scatter(x, y; legend=false, dpi=200)



function plotgps(pred, x, y)
    plt = plot(;dpi=200)
    xx = collect(range(minimum(x)-0.5, maximum(x)+0.5; length=200))
    for p in pred
        try
            gp = posterior(p._y_dist, y)
            plot!(plt, xx, rand(gp(xx,1e-9),2); alpha=0.01, color="black", legend=false)
        catch 
        end
    end
    scatter!(plt, x, y; color=1)
    ylims!(plt, -2.5, 2.5)
    return plt
end

plotgps(pred, x, y)


particles(post)



[posterior(p._y_dist, y) for p in predict(Soss.withdistributions(m)(x=x), post)]