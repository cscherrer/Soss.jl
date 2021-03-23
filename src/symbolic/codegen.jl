
using SymbolicCodegen
using MacroTools: @q


using SymbolicCodegen
import SymbolicCodegen

export codegen

function SymbolicCodegen.codegen(cm :: ConditionalModel; kwargs...)

    code = codegen(get(kwargs, :ℓ, symlogdensity(cm)))

    m = Model(cm)
    for (v, rhs) in pairs(m.vals)
        pushfirst!(code.args, :($v = $rhs))
    end

    for v in parameters(m)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_args, $vname)))
    end

    for v in observed(cm)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_data, $vname)))
    end

    for v in setdiff(sampled(m), observed(cm))
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_pars, $vname)))
    end


    return mk_function(getmodule(cm), (:_args, :_data, :_pars), (), code)

end



export sourceCodegen

function sourceCodegen(cm :: ConditionalModel)
    codegen(symlogdensity(cm))
end
