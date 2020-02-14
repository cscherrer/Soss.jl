### Define the target distribution and its gradient
using Distributions: logpdf, MvNormal
using DiffResults: GradientResult, value, gradient
using ForwardDiff: gradient!


### Build up a HMC sampler to draw samples
using AdvancedHMC



export advancedHMC


function advancedHMC(m :: JointDistribution{A,B}, _data, N = 1000; 
                                                         n_adapts  = 1000) where {A,B}
    
    ℓ(pars) = logpdf(m, merge(pars, _data))

    t = xform(m,_data)

    function f(x) 
        (θ, logjac) = transform_and_logjac(t,x)
        ℓ(θ) + logjac
    end

    
    function ∂f(x)
        res = GradientResult(x)
        gradient!(res, f, x)
        return (value(res), gradient(res))
    end

    # Sampling parameter settings


    D = t.dimension
    # Draw a random starting points
    x_init = randn(D)

    # Define metric space, Hamiltonian, sampling method and adaptor
    metric = DiagEuclideanMetric(D)
    h = Hamiltonian(metric, f, ∂f)
    prop = AdvancedHMC.NUTS(Leapfrog(find_good_eps(h, x_init)))
    adaptor = StanHMCAdaptor(n_adapts, Preconditioner(metric), NesterovDualAveraging(0.8, prop.integrator.ϵ))

    # Draw samples via simulating Hamiltonian dynamics
    # - `samples` will store the samples
    # - `stats` will store statistics for each sample
    samples, stats = sample(h, prop, x_init, N, adaptor, n_adapts; progress=true)

end


