### Define the target distribution and its gradient
using Distributions: logpdf, MvNormal
using DiffResults: GradientResult, value, gradient
using ForwardDiff: gradient!

const D = 10
const target = MvNormal(zeros(D), ones(D))
ℓπ(θ) = logpdf(target, θ)

function ∂ℓπ∂θ(θ)
    res = GradientResult(θ)
    gradient!(res, ℓπ, θ)
    return (value(res), gradient(res))
end

### Build up a HMC sampler to draw samples
using AdvancedHMC

# Sampling parameter settings
n_samples = 100_000
n_adapts = 2_000

# Draw a random starting points
θ_init = randn(D)

# Define metric space, Hamiltonian, sampling method and adaptor
metric = DiagEuclideanMetric(D)
h = Hamiltonian(metric, ℓπ, ∂ℓπ∂θ)
prop = NUTS(Leapfrog(find_good_eps(h, θ_init)))
adaptor = StanHMCAdaptor(n_adapts, Preconditioner(metric), NesterovDualAveraging(0.8, prop.integrator.ϵ))

# Draw samples via simulating Hamiltonian dynamics
# - `samples` will store the samples
# - `stats` will store statistics for each sample
samples, stats = sample(h, prop, θ_init, n_samples, adaptor, n_adapts; progress=true)