module Soss

import Base.rand
using Random
using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns
using NamedTupleTools

import MacroTools: prewalk, postwalk, @q, striplines, replace, flatten, @capture
import MLStyle
@reexport using MonteCarloMeasurements

using LazyArrays
using FillArrays
using Requires

include("core/statement.jl")
include("core/model.jl")
include("core/jointdistribution.jl")
include("core/canonical.jl")
include("core/dependencies.jl")
include("core/toposort.jl")
include("core/weighted.jl")
include("core/utils.jl")

include("distributions/dist.jl")
include("distributions/for.jl")
include("distributions/iid.jl")
include("distributions/mix.jl")
# include("distributions/flat.jl")
include("distributions/markovchain.jl")

include("primitives/rand.jl")
include("primitives/logpdf.jl")
include("primitives/xform.jl")
include("primitives/likelihood-weighting.jl")
@init @require Bijectors="76274a88-744f-5084-9051-94815aaf08c4" begin
    include("primitives/bijectors.jl")
end

include("transforms/predictive.jl")
include("transforms/markovblanket.jl")
include("transforms/do.jl")
include("transforms/prune.jl")
include("transforms/prior.jl")

include("symbolic/symbolic.jl")
include("symbolic/codegen.jl")

include("particles.jl")
include("plots.jl")

include("inference/rejection.jl")
include("inference/dynamicHMC.jl")
include("inference/advancedhmc.jl")


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
