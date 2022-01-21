### Define the target distribution and its gradient
using DiffResults: GradientResult
import DiffResults
using ForwardDiff: gradient!


### Build up a HMC sampler to draw samples
using AdvancedHMC



export advancedHMC



"""
    advancedHMC(m, data, N = 1000; n_adapts = 1000)

Draw `N` samples from the posterior distribution of parameters defined in Soss model `m`, conditional on `data`. Samples are drawn using Hamiltonial Monte Carlo (HMC) from the `advancedHMC.jl` package.

## Keywords
*  `n_adapts = 1000`: The number of interations used to set HMC parameters.

Returns a tuple of length 2:
1. Samples from the posterior distribution of parameters.
2. Sample summary statistics.

## Example

```
m = @model x begin
    β ~ Normal()
    yhat = β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], 2.0)
    end
end

x = randn(10);
truth = [0.61, -0.34, -1.74];

post = advancedHMC(m(x=x), (y=truth,));
E_β = mean(post[1])[1]

println("Posterior mean β: " * string(round(E_β, digits=2)))
```



"""
function advancedHMC(m :: ModelClosure{A,B}, _data, N = 1000;
                                                         n_adapts  = 1000) where {A,B}

    ℓ(pars) = logdensity_def(m, merge(pars, _data))

    t = xform(m,_data)

    function f(x)
        (θ, logjac) = transform_and_logjac(t,x)
        ℓ(θ) + logjac
    end


    function ∂f(x)
        res = GradientResult(x)
        gradient!(res, f, x)
        return (DiffResults.value(res), DiffResults.gradient(res))
    end

    # Sampling parameter settings


    D = t.dimension
    # Draw a random starting points
    initial_θ = randn(D)

    # Define metric space, Hamiltonian, sampling method and adaptor
    metric = DiagEuclideanMetric(D)
    hamiltonian = Hamiltonian(metric, f, ∂f)
    prop = AdvancedHMC.NUTS(Leapfrog(find_good_stepsize(hamiltonian, initial_θ)))
    initial_ϵ = find_good_stepsize(hamiltonian, initial_θ)
    integrator = Leapfrog(initial_ϵ)
    adaptor = StanHMCAdaptor(MassMatrixAdaptor(metric), StepSizeAdaptor(0.8, integrator))

    # Draw samples via simulating Hamiltonian dynamics
    # - `samples` will store the samples
    # - `stats` will store statistics for each sample
    samples, stats = simulate(hamiltonian, prop, initial_θ, N, adaptor, n_adapts; progress=false, verbose=false)

end
