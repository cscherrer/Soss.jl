module Soss

import Base.rand
using Random
using Reexport: @reexport

@reexport using Measures
using Measures: Normal
@reexport using StatsFuns
using NamedTupleTools

import MacroTools: prewalk, postwalk, @q, striplines, replace, flatten, @capture
import MLStyle
# @reexport using MonteCarloMeasurements

@reexport using SossBase
using SossBase: JointDistribution, Assign, Sample, Return, findStatement,
    LineNumber, getmoduletypencoding, type2model, getntkeys, buildSource, loadvals
import SossBase: logdensity

using GeneralizedGenerated
using GeneralizedGenerated: TypeLevel

using LazyArrays
using FillArrays

# include("distributions/dist.jl")
include("distributions/for.jl")
# include("distributions/iid.jl")
# include("distributions/mix.jl")
# # include("distributions/flat.jl")
# include("distributions/markovchain.jl")

# include("primitives/xform.jl")
# # include("primitives/bijectors.jl")

# include("symbolic/symbolic.jl")
# include("symbolic/codegen.jl")

# include("particles.jl")
# include("plots.jl")

# include("inference/rejection.jl")
# include("inference/dynamicHMC.jl")
# include("inference/advancedhmc.jl")


# include("weighted.jl")
#
# # include("graph.jl")
# # # include("optim.jl")
# include("importance.jl")
#
# # # include("sobols.jl")
# # # include("fromcube.jl")
# # # include("tocube.jl")
end # module
