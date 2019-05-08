module Soss

import Base.rand
using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns

import MacroTools: prewalk, postwalk, @q, striplines, replace, flatten, @capture
import MLStyle

include("statement.jl")
# include("ast.jl")
include("model.jl")
# include("weighted.jl")
# include("rand.jl")
# include("dist.jl")
include("utils.jl")
# include("iid.jl")
# include("for.jl")
# include("flat.jl")
include("examples.jl")
# include("bijections.jl")
# include("graph.jl")
# include("nuts.jl")
# include("optim.jl")
# include("importance.jl")
# include("canonical.jl")


end # module
