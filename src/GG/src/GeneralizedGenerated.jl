module GeneralizedGenerated
using MLStyle
using JuliaVariables
using DataStructures
List = LinkedList

export NGG
export gg, @gg, UnderGlobal, @under_global
export RuntimeFn, closure_conv, mk_function, mkngg, mk_expr
export to_type, from_type, runtime_eval
include("closure_conv.jl")


function mk_function(ex)
    mk_function(@__MODULE__, ex)
end

function mk_function(mod::Module, ex)
    ex = macroexpand(mod, ex)
    ex = simplify_ex(ex)
    ex = solve!(ex)
    fn = closure_conv(mod, ex)
    if !(fn isa RuntimeFn)
        error("Expect an unnamed function expression. ")
    end
    fn
end

"""
process an expression and perform closure conversions for all nested expressions.
"""
function mk_expr(mod::Module, ex)
    ex = macroexpand(mod, ex)
    ex = simplify_ex(ex)
    ex = solve!(ex)
    closure_conv(mod, ex)
end


function mk_function(mod::Module, args, kwargs, body)
    mk_function(mod, Expr(:function, :($(args...), ; $(kwargs...)), body))
end

function mk_function(args, kwargs, body)
    mk_function(Main, args, kwargs, body)
end

function runtime_eval(mod::Module, ex)
    fn_ast = :(function ()
        $ex
    end)
    mk_function(mod, fn_ast)()
end

function runtime_eval(ex)
    runtime_eval(Main, ex)
end

end # module
