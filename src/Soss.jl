module Soss

using Distributions
using StatsFuns
using MacroTools
using MacroTools: postwalk, @q, prettify
using StaticArrays

include("core.jl")
include("utils.jl")
include("for.jl")
include("examples.jl")

end # module
