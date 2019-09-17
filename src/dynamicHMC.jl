using TransformVariables, LogDensityProblems, DynamicHMC, MCMCDiagnostics, Parameters,
    Distributions, Statistics, StatsFuns, ForwardDiff

using Random

export dynamicHMC

# import Flux
function dynamicHMC(m :: JointDistribution, _data, N=1000::Int) 
    ℓ(pars) = logpdf(m, merge(pars, _data))

    t = xform(m,_data)
    P = TransformedLogDensity(t, ℓ)
    ∇P = ADgradient(Val(:ForwardDiff), P)
    results = mcmc_with_warmup(MersenneTwister(), ∇P, N; reporter=DynamicHMC.NoProgressReport());
    samples = TransformVariables.transform.(parent(∇P).transformation, results.chain)
end


function dynamicHMC(m :: JointDistribution, _data, ::Val{Inf}) 
    ℓ(pars) = logpdf(m, merge(pars, _data))

    t = xform(m,_data)
    P = TransformedLogDensity(t, ℓ)
    ∇P = ADgradient(Val(:ForwardDiff), P)
    
    # initialization
    rng = MersenneTwister()
    results = DynamicHMC.mcmc_keep_warmup(rng, ∇P, 0; reporter = NoProgressReport())
    steps = DynamicHMC.mcmc_steps(results.sampling_logdensity, results.final_warmup_state)

    (results, steps)
end


using ResumableFunctions

export stream
@resumable function stream(m :: JointDistribution, _data::NamedTuple) 
    t = xform(m, _data)
    (results, steps) = dynamicHMC(m, _data, Val(Inf))
    Q = results.final_warmup_state.Q
    while true
        Q, tree_stats = DynamicHMC.mcmc_next_step(steps, Q)
        @yield (merge(t(Q.q), (_ℓ = Q.ℓq,)), tree_stats)
    end
end

