module Soss

import Base.rand
using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns

using MacroTools
using MacroTools: prewalk, postwalk, @q, striplines, replace, flatten


include("model.jl")
include("weighted.jl")
include("rand.jl")
include("dist.jl")
include("bijections.jl")
include("utils.jl")
include("iid.jl")
include("for.jl")
include("examples.jl")
include("graph.jl")
include("nuts.jl")

end # module
