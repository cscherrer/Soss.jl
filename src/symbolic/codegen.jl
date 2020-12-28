
using GeneralizedGenerated: runtime_eval
using MacroTools: @q

export codegen

# moved to __init__
# @gg function codegen(_m::Model, _args, _data)
#     f = _codegen(type2model(_m))
#     :($f(_args, _data))
# end

function _codegen(m :: Model, expand_sums=true)
    s = symlogdensity(m)

    if expand_sums
        s = expandSums(s) |> foldConstants
    end

    code = codegen(s)

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


    f = mk_function(:((_args, _data) -> $code))

    return f
end

# @generated function _codegen(_m::Model, _args, _data)
#     type2model(_m) |> sourceCodegen() |> loadvals(_args, _data)
# end

# export sourceCodegen
# function sourceCodegen()
#     function(_m::Model)
#         body = @q begin end

#         for (x, rhs) in pairs(_m.vals)
#             push!(body.args, :($x = $rhs))
#         end

#         push!(body.args, eval(:(codegen(symlogdensity($_m)))))
#         return body
#     end
# end

export codegen

function codegen end

function logdensity(m::ConditionalModel{A0,A,B,M},x,::typeof(codegen)) where {A0,A,B,M}
    codegen(M, m.model, m.args, x)
end
