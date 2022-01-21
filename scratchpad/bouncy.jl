using Soss
using Soss: ModelClosure
using ZigZagBoomerang
# using Makie
### Define the target distribution and its gradient
using ForwardDiff: gradient!
using LinearAlgebra
using SparseArrays
using NamedTupleTools: select
using TransformVariables

"""
    bouncy(m, data, T = 1000.0; c=10.0, λ=0.1, ρ=0.0, adapt=false)
Draw  samples until time `T` from the posterior distribution of parameters defined in Soss model `m`, conditional on `data`.
Samples are drawn using the Bouncy particle sampler.
Returns a `Trace` object. 
"""
function bouncy(m::ModelClosure, T = 1000.0;  c=10.0, λref=0.1, ρ=0.0, adapt=false) where {A,B}

    ℓ(pars) = logdensity_def(m, pars)

    t = xform(m)

    function f(x)
        (θ, logjac) = transform_and_logjac(t, x)
        -ℓ(θ) - logjac
    end


    function ∇ϕ!(y, x)
        gradient!(y, f, x)
        y
    end

    # Draw a random starting points and velocity
    d = t.dimension

    tkeys = keys(t(zeros(d)))
    r = select(rand(m), tkeys)
    x0 = inverse(t, r)

    t0 = 0.0
    θ0 = randn(d)
    
    pdmp(∇ϕ!, t0, x0, θ0, T, c, BouncyParticle(sparse(I(d)), 0*x0, λref, ρ); adapt=adapt)

end

m = @model x begin
    α ~ Normal()
    β ~ Normal()
    yhat = α .+ β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], 2.0)
    end
end

x = randn(3);
truth = [0.61, -0.34, -1.74];

post = m(x=x) | (y=truth,)

trace, final, (num, acc) = @time bouncy(post, c=10)

ts, xs = ZigZagBoomerang.sep(discretize(trace, 0.1)) 

p = lines(ts, getindex.(xs, 1))
lines!(ts, getindex.(xs, 2), color=:red)

p
