module Soss

import Base.rand
using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns
using NamedTupleTools

import MacroTools: prewalk, postwalk, @q, striplines, replace, flatten, @capture
import MLStyle
@reexport using MonteCarloMeasurements


include("statement.jl")
include("model.jl")
# include("weighted.jl")

include("for.jl")
include("dist.jl")
# include("flat.jl")
include("iid.jl")
include("utils.jl")
include("dependencies.jl")
include("logpdf.jl")
include("weighted.jl")
include("likelihood-weighting.jl")
# include("examples.jl")
# include("graph.jl")
include("dynamicHMC.jl")
# # include("optim.jl")
include("importance.jl")
include("canonical.jl")
include("symbolic.jl")
include("codegen.jl")
# # include("sobols.jl")
# # include("fromcube.jl")
# # include("tocube.jl")
include("particles.jl")
include("xform.jl")
include("toposort.jl")
include("advancedhmc.jl")
# include("plots.jl")
# include("rejection.jl")
include("rand.jl")
include("predictive.jl")
include("mix.jl")
# include("plots.jl")
include("markovblanket.jl")
end # module
