using SymPy
import PyCall

using SymPy
import PyCall
stats = PyCall.pyimport_conda("sympy.stats", "sympy")
import_from(stats)

# macro symport(s)
#     str = "sympy.$s"
#     quote
#         $s = PyCall.pyimport_conda($str, "sympy")
#         import_from($s)
#     end
# end


using MacroTools
using MacroTools: postwalk

function getsymbols(expr ::Expr) :: Vector{Symbol}
    result = []
    postwalk(expr) do x
        if @capture(x, s_symbol_Symbol)
            union!(result, [s])
        end
    end
    result
end

"""
    @getlogpdf(expr, params)

Transform a distributional statement
    v ~ dist(args...)
into an expression for the log-density

WARNING
For now, this only work with distributions that have the same name and parameterization in SymPy and Distributions.jl
"""
macro getlogpdf(expr, params)
    params = params.args
    vars = params ∩ getsymbols(expr) 
    # @show vars

    sym = Dict(v => SymPy.symbols(v) for v in vars )
    # @show sym

    @assert @capture(expr, v_ ~ rhs_)

    # e.g., :(Normal(μ,σ)) -> :(SymPy.Normal(v,μ,σ))
    rhs.args[1] = :(SymPy.$(rhs.args[1]))
    splice!(rhs.args, 2:1, [v])
    
    s = postwalk(rhs) do x
        if x∈vars
            sym[x]
        else x
        end
    end

    s = :(SymPy.density($s).pdf($(sym[v])) |> log)
    s = :(expand($s,log=true,deep=false,force=true))
    # s = :(Meta.parse(repr($s)))
    s 

end 

# @getlogpdf(x ~ Normal(μ+σ,σ), [x, μ,σ,ν])
