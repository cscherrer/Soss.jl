module Soss

using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns

using MacroTools
using MacroTools: postwalk, @q, striplines, replace


include("model.jl")
include("dist.jl")
include("bijections.jl")
include("utils.jl")
include("iid.jl")
include("for.jl")
include("examples.jl")
include("graph.jl")

end # module
