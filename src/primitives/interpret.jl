export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0, call=nothing) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(m.body, tilde, ctx0; call=call))
end

function _interpret(ast::Expr, _tilde, call=nothing)
    function branch(head, newargs)
        expr = Expr(head, newargs...)
        (head, newargs[1]) == (:call, :~) || return expr
        length(newargs) == 3 || return expr

        (_, x, d) = newargs
        qx = QuoteNode(x)
        quote
            ($x, _ctx, _retn) = $_tilde($qx, $d, _cfg, _ctx)
        end
    end

    body = foldall(identity, branch)(ast)

    if !isnothing(call)
        body = callify(body; call=call)
    end

    body
end

@gg function mkfun(_mc, tilde, call)
    _m = type2model(_mc)
    M = getmodule(_m)

    _args = argvalstype(_mc)
    _obs = obstype(_mc)

    tilde = tilde.instance
    call = call.instance
     
    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(body, tilde, call)

    q = (@q let M
        function(_cfg, _ctx)
            local _retn
            _args = Soss.argvals(_mc)
            _obs = Soss.observations(_mc)
            _cfg = merge(_cfg, (_args=_args, _obs=_obs))
            $body
            _retn
        end
    end) |> MacroTools.flatten
end
