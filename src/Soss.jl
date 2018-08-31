module Soss

export arguments, @model, For, Eval, logdensity, observe, parameters, supports, lda, sampleFrom, linReg1D

using Reexport: @reexport

@reexport using Distributions

using StatsFuns
using MacroTools
using MacroTools: postwalk, @q, striplines, replace


include("core.jl")
include("utils.jl")
include("for.jl")
include("examples.jl")

end # module
