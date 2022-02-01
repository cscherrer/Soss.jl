export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(theModule, m.body, tilde, ctx0))
end

function _interpret(M, ast::Expr, _tilde, _args, _obs)
    function go(ex)
        @match ex begin
            :($x ~ $d) => begin
                x = x.name
                qx = QuoteNode(x)
                xname = to_type(x)
                measure = to_type(d)
                inargs = static(x ∈ getntkeys(_args))
                inobs = static(x ∈ getntkeys(_obs))
                varnames = locals(d)
                varvals = Expr(:tuple, varnames...)
                quote
                    ($x, _ctx, _retn) = let targs = Soss.TildeArgs($xname, $measure, NamedTuple{$varnames}($varvals), $inargs, $inobs)
                        $_tilde($qx, $d, _cfg, _ctx, targs)
                    end
                end
            end

            Expr(head, args...) => Expr(head, map(go, args)...)
            
            x => x
        end
    end


    body = go(@q let 
            $(solve_scope(ast)).args[2]
    end) |> unsolve

    body
end

@gg function mkfun(_mc::MC, ::T) where {MC, T}
    _m = type2model(MC)
    M = getmodule(_m)

    _args = argvalstype(MC)
    _obs = obstype(MC)

    tilde = T.instance
     
    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(M, body, tilde, _args, _obs)

    q = MacroTools.flatten(@q let M
        @inline function(_cfg, _ctx)
            local _retn
            _args = Soss.argvals(_mc)
            _obs = Soss.observations(_mc)
            _cfg = merge(_cfg, (_args=_args, _obs=_obs))
            $body
            _retn
        end
    end)

    @under_global M q
end
