module Soss

export arguments, @model, For, Eval, logdensity, observe, parameters, supports, lda, sampleFrom, linReg1D

using Reexport: @reexport

@reexport using Distributions
@reexport using StatsFuns

using MacroTools
using MacroTools: postwalk, @q, striplines, replace


include("model.jl")
include("utils.jl")
include("iid.jl")
include("for.jl")
include("examples.jl")
# include("nuts.jl")

end # module
