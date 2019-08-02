using TransformVariables, LogDensityProblems, DynamicHMC, MCMCDiagnostics, Parameters,
    Distributions, Statistics, StatsFuns, ForwardDiff

struct NUTS_result{T}
    chain::Vector{NUTS_Transition{Vector{Float64},Float64}}
    transformation
    samples::Vector{T}
    tuning
end

Base.show(io::IO, n::NUTS_result) = begin
    println(io, "NUTS_result with samples:")
    println(IOContext(io, :limit => true, :compact => true), n.samples)
end

export nuts

@inline function invokefrozen(f, rt, args...; kwargs...)
    if isempty(kwargs)
        return _invokefrozen(f, rt, args)
    end
    # We use a closure (`inner`) to handle kwargs.
    inner() = f(rt, args...; kwargs...)
    _invokefrozen(inner)
end

@inline @generated function _invokefrozen(f, ::Type{rt}, args...) where rt
  tupargs = Expr(:tuple,(a==Nothing ? Int : a for a in args)...)
  quote
    _f = $(Expr(:cfunction, Base.CFunction, :f, rt, :((Core.svec)($((a==Nothing ? Int : a for a in args)...))), :(:ccall)))
    return ccall(_f.ptr,rt,$tupargs,$((:(getindex(args,$i) === nothing ? 0 : getindex(args,$i)) for i in 1:length(args))...))
  end
end

# TODO: possibly make this an intrinsic
inferencebarrier(@nospecialize(x)) = Ref{Any}(x)[]


function nuts(m :: Model; kwargs...)
    result = NUTS_result{}
    t = xform(m; kwargs...)
    fpre = @eval $(sourceLogdensity(m))
    # fpre = @logdensity m
    f(pars) = invokefrozen(fpre, Float64, merge(kwargs, pairs(pars)))
    # f(pars) = invoke(fpre, merge(kwargs, pairs(pars)))
    P = TransformedLogDensity(t, f)
    ∇P = ADgradient(:ForwardDiff, P)
    chain, tuning = NUTS_init_tune_mcmc(∇P, 1000);
    samples = TransformVariables.transform.(Ref(parent(∇P).transformation), get_position.(chain));
    NUTS_result(chain, t, samples, tuning)
end
