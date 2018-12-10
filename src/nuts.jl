using TransformVariables, LogDensityProblems, DynamicHMC, MCMCDiagnostics, Parameters,
    Distributions, Statistics, StatsFuns, ForwardDiff

struct NUTS_result{T}
    chain :: Vector{NUTS_Transition{Vector{Float64},Float64}}
    transformation
    samples :: Vector{T}
    tuning
end

Base.show(io::IO, n::NUTS_result) = begin
    println(io,"NUTS_result with samples:")
    println(IOContext(io, :limit=>true, :compact=>true), n.samples)
end

export nuts

function nuts(model; data=NamedTuple{}(), numSamples = 1000)
    result = NUTS_result{}
    t = getTransform(model)

    fpre = eval(logdensity(model))
    f(par) = Base.invokelatest(fpre,par,data)

    P = TransformedLogDensity(t,f)
    ∇P = ADgradient(:ForwardDiff,P)
    chain, tuning = NUTS_init_tune_mcmc(∇P, numSamples);
    samples = transform.(Ref(∇P.transformation), get_position.(chain));
    NUTS_result(chain, t, samples, tuning)
end
