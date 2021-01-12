
using GeneralizedGenerated: runtime_eval
using SymbolicCodegen
using MacroTools: @q


using SymbolicCodegen
import SymbolicCodegen

export codegen

function SymbolicCodegen.codegen(cm :: ConditionalModel)
    code = sourceCodegen(cm)

    m = Model(cm)
    for (v, rhs) in pairs(m.vals)
        pushfirst!(code.args, :($v = $rhs))
    end

    for v in arguments(m)
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


    f = mk_function(getmodule(cm), (:_args, :_data, :_pars), (), code)

    result = function(cm, x) f(cm.argvals, cm.obs, x) end
    return result
end

export sourceCodegen

function sourceCodegen(cm :: ConditionalModel)
    codegen(symlogdensity(cm))
end
