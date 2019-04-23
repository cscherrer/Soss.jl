module Soss

import Base.rand
using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns

using MacroTools
using MacroTools: prewalk, postwalk, @q, striplines, replace, flatten

include("utils.jl")
# include("model.jl")
# include("weighted.jl")
# include("rand.jl")
# include("dist.jl")
# include("utils.jl")
# include("iid.jl")
# include("for.jl")
# include("flat.jl")
# include("examples.jl")
# include("bijections.jl")
# include("graph.jl")
# include("nuts.jl")

end # module
