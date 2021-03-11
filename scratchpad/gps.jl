using Soss
using AbstractGPs
using KernelFunctions

x = randn(100)
y = sinpi.(x) + 0.3*randn(100)


import TransformVariables
const TV = TransformVariables 
Soss.xform(gp::AbstractGPs.FiniteGP, _data=NamedTuple()) = TV.as(Array, TV.asℝ,size(gp)...)

sqexpkernel(alpha::Real, rho::Real) = 
alpha^2 * transform(SEKernel(), 1/(rho*sqrt(2)))
using LinearAlgebra
using PositiveFactorizations

# Define model. 
m = @model x begin
    # Priors.
    alpha ~ LogNormal(0.0, 0.1)
    rho ~ LogNormal(0.0, 1.0)
    sigma ~ LogNormal(0.0, 1.0)
    
    # Covariance function.
    kernel = sqexpkernel(alpha, rho)
    
    # GP (implicit zero-mean).
    gp = GP(kernel)

    y ~ gp(x, 0.6+sigma^2)
    # Sampling Distribution (MvNormal likelihood).
    # y ~ gp(x, sigma^2 + 1e-6)  # add 1e-6 for numerical stability.
end;

PositiveFactorizations.floattype(::Type{T}) where {T} = T


post = dynamicHMC(m(x=x), (;y=y); ad_backend=Val(:Zygote));
particles(post)

gp1 = predict(m(x=x), post[1]).gp(x, post[1].sigma^2 + 1e-6)

gp1post = posterior(gp1, y)

using Plots
plt = scatter(x, y; label = "Data")
plot!(plt, gp1post, range(extrema(x)...; length=100); label="Posterior")

plot(gp1post)
