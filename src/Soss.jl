module Soss

import Base.rand
using Random
using Reexport: @reexport



@reexport using StatsFuns
@reexport using MeasureTheory

using NamedTupleTools

using SymbolicCodegen
import MacroTools: prewalk, postwalk, @q, striplines, replace, @capture
import MacroTools
import MLStyle
# import MonteCarloMeasurements
# using MonteCarloMeasurements: Particles, StaticParticles, AbstractParticles

using LazyArrays
using FillArrays
using Requires

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

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
# include("distributions/iid.jl")
# include("distributions/mix.jl")
# include("distributions/flat.jl")
# include("distributions/markovchain.jl")

include("primitives/rand.jl")
include("simulate.jl")
include("primitives/logpdf.jl")
include("primitives/xform.jl")
include("primitives/likelihood-weighting.jl")
# @init @require Bijectors="76274a88-744f-5084-9051-94815aaf08c4" begin
#     include("primitives/bijectors.jl")
# end
include("primitives/entropy.jl")

include("transforms/predict.jl")
include("transforms/markovblanket.jl")
include("transforms/utils.jl")
include("transforms/basictransforms.jl")
include("transforms/withdistributions.jl")

include("symbolic/symarray.jl")
include("symbolic/symbolic.jl")
include("symbolic/codegen.jl")
# include("symbolic/codegen-sympy.jl") 

# include("particles.jl")
include("plots.jl")

include("inference/rejection.jl")
include("inference/dynamicHMC.jl")
include("inference/advancedhmc.jl")

#
# # include("graph.jl")
# # # include("optim.jl")
include("importance.jl")
#
# # # include("sobols.jl")
# # # include("fromcube.jl")
# # # include("tocube.jl")
end # module
