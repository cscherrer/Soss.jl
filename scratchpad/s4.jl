using MeasureTheory
using ConcreteStructs

import MeasureTheory: logdensity

@concrete terse struct Chain <: AbstractMeasure
    κ
    μ
end

evolve(mc::MarkovChain, μ) =  μ ⋅ mc.κ
evolve(mc::MarkovChain, ::Nothing) =  mc.μ

function dyniterate(mc::MarkovChain, u::Sample)
    xnew =  rand(u.rng, evolve(mc, Dirac(u.x)))
    xnew, Sample(u.rng, xnew)
end



function logdensity_def(mc::Chain, x)
    μ = mc.μ
    ℓ = 0.0
    for xj in x
        ℓ += logdensity_def(μ, xj)
        μ = mc.κ(xj)
    end
    return ℓ
end

mc = Chain(Normal()) do x Normal(μ=x) end

logdensity_def(mc, randn(100))


using Soss

hmm = @model begin
    ε ~ Exponential() #  transition
    σ ~ Exponential() # Observation noise
    x ~ Chain(Normal()) do xj
        Normal(xj, ε)
    end

    y ~ For(x) do xj
        Normal(xj, σ)
    end
end

using Soss

mbind = @model μ,next begin
    x ~ μ
    y ~ next(x)
    return y
end;

mbind2 = @model μ,next begin
    x ~ μ
    y ~ next(last(x))
    return (x...,y)
end;


⋅(μ,next) = mbind(μ,next)

⊛(μ,next) = mbind2(μ,next);

next(x) = Normal(x+1,1);

d =  Normal() ⋅ next ⋅ next ⋅ next

μ0 = @model d begin
    x ~ d
    return (x,)
end

d2 = (Normal()^1) ⊛ next ⊛ next ⊛ next

rand(d)
rand(d2)

simulate(d)

t = xform(d);
t(randn(4))


# julia> d =  Cauchy() ⋅ (x -> Normal(μ=x)) ⋅ (x -> Normal(μ=x)) ⋅ (x -> Normal(μ=x))
# ConditionalModel given
#     arguments    (:μ, :κ)
#     observations ()
# @model (μ, κ) begin
#         x ~ μ
#         y ~ κ(x)
#         return y
#     end



# julia> rand(d)
# -3.0414465047589037

# julia> t = xform(d)
# TransformVariables.TransformTuple{NamedTuple{(:x, :y), Tuple{TransformVariables.TransformTuple{NamedTuple{(:x, :y), Tuple{TransformVariables.TransformTuple{NamedTuple{(:x, :y), Tuple{TransformVariables.Identity, TransformVariables.Identity}}}, TransformVariables.Identity}}}, TransformVariables.Identity}}}((x = TransformVariables.TransformTuple{NamedTuple{(:x, :y), Tuple{TransformVariables.TransformTuple{NamedTuple{(:x, :y), Tuple{TransformVariables.Identity, TransformVariables.Identity}}}, TransformVariables.Identity}}}((x = TransformVariables.TransformTuple{NamedTuple{(:x, :y), Tuple{TransformVariables.Identity, TransformVariables.Identity}}}((x = asℝ, y = asℝ), 2), y = asℝ), 3), y = asℝ), 4)

# julia> t(randn(4))
# (x = (x = (x = -0.24259286698966315, y = 0.278190893626807), y = -1.361907586870645), y = 0.05914265096096323)

# julia> simulate(d)
# (value = 5.928939554009484, trace = (x = (value = 5.307006358072237, trace = (x = (value = 3.2023770380851797, trace = (x = 3.677550124255551, y = 3.2023770380851797)), y = 5.307006358072237)), y = 5.928939554009484))
