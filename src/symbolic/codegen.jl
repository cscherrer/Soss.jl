
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

    for v in sampled(m)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_data, $vname)))
    end

    code = MacroTools.flatten(:((_args, _data) -> $code))

    f = mk_function(code)

    return f
end

export sourceCodegen

function sourceCodegen(cm :: ConditionalModel)
    assignments = cse(symlogdensity(cm))

    q = @q begin end

    for a in assignments
        x = a[1]
        rhs = codegen(a[2])
        push!(q.args, @q begin $x = $rhs end)
    end

    MacroTools.flatten(q)
end
