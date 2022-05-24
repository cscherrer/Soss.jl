module Soss

import BayesianLinearRegression
import Base.rand
using Random
using Reexport: @reexport

@reexport using StatsFuns
@reexport using MeasureTheory
using MeasureBase: productmeasure, Returns

import DensityInterface: logdensityof
import DensityInterface: densityof
import DensityInterface: DensityKind
using DensityInterface

using NamedTupleTools
using SampleChains
# using SymbolicCodegen

using SymbolicUtils: Symbolic
const MaybeSym{T} = Union{T, Symbolic{T}}

import MacroTools: prewalk, postwalk, @q, striplines, replace, @capture
import MacroTools
import MLStyle
# import MonteCarloMeasurements
# using MonteCarloMeasurements: Particles, StaticParticles, AbstractParticles

using Requires
using ArrayInterface: StaticInt
using Static

using IfElse: ifelse
using TransformVariables: asℝ, as𝕀, asℝ₊
import TransformVariables
const TV = TransformVariables

using SimplePosets: SimplePoset

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)
using MeasureBase: AbstractTransitionKernel

using MeasureTheory: ∞
@reexport using MeasureTheory
import MeasureTheory: as

"""
we use this to avoid introduce static type parameters
for generated functions
"""
_unwrap_type(a::Type{<:Type}) = a.parameters[1]

import GeneralizedGenerated as GG


include("noted.jl")
include("core/models/abstractmodel.jl")
include("core/statement.jl")
include("core/models/model.jl")
# include("core/models/jointdistribution.jl")
include("core/canonical.jl")
include("core/dependencies.jl")
include("core/toposort.jl")
include("core/weighted.jl")
include("core/utils.jl")
include("core/models/conditional.jl")

# include("distributions/dist.jl")
# include("distributions/for.jl")
include("distributions/iid.jl")
# include("distributions/mix.jl")
# include("distributions/flat.jl")
# include("distributions/markovchain.jl")

include("primitives/rand.jl")
include("primitives/simulate.jl")
include("primitives/logdensity.jl")
include("primitives/as.jl")
include("primitives/likelihood-weighting.jl")
include("primitives/insupport.jl")
# include("primitives/gg.jl")
# @init @require Bijectors="76274a88-744f-5084-9051-94815aaf08c4" begin
#     include("primitives/bijectors.jl")
# end

include("primitives/basemeasure.jl")
include("primitives/testvalue.jl")
# include("primitives/entropy.jl")


include("transforms/predict.jl")
include("transforms/markovblanket.jl")
include("transforms/utils.jl")
include("transforms/basictransforms.jl")
include("transforms/withmeasures.jl")

# include("symbolic/symcall.jl")
# include("symbolic/symify.jl")
# include("symbolic/rules.jl")
# include("symbolic/symbolic.jl")
# include("symbolic/codegen.jl")

# include("particles.jl")
include("plots.jl")

include("inference/rejection.jl")
# include("inference/dynamicHMC.jl")
# include("inference/advancedhmc.jl")
include("inference/power-posterior.jl")
# include("inference/Δlogdensity.jl")

#
# # include("graph.jl")
# # # include("optim.jl")
include("importance.jl")
#


function __init__()
    @require SampleChainsDynamicHMC = "6d9fd711-e8b2-4778-9c70-c1dfb499d4c4" begin
        include("samplechains/dynamichmc.jl")
    end
end

# # # include("sobols.jl")
# # # include("fromcube.jl")
# # # include("tocube.jl")
end # module
