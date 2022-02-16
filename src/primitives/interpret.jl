export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(theModule, m.body, tilde, ctx0))
end

function _interpret(M, ast::Expr, _tilde, _args, _obs)
    function go(ex, scope=(bounds = Var[], freevars = Var[], bound_inits = Symbol[]))
        @match ex begin
            :($x ~ $d) => begin
                x = unsolve(x)
                qx = QuoteNode(x)
                xname = to_type(x)
                measure = to_type(d)
                varnames = Tuple(locals(d) ∩ scope.bound_inits)
                varvals = Expr(:tuple, varnames...)
                quote
                    ($x, _ctx, _retn) = let targs = Soss.TildeArgs(NamedTuple{$varnames}($varvals), $xname, $measure)
                        $_tilde($qx, $d, _cfg, _ctx, targs)
                    end

                    _retn isa Soss.ReturnNow && return _retn.value
                end
            end

            Expr(:scoped, new_scope, ex) => begin
                go(ex, new_scope)
            end

            Expr(head, args...) => Expr(head, map(go, args)...)
            
            x => x
        end
    end


    body = go(@q let 
            $(solve_scope(ast))
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
            _cfg = merge(_cfg, (args=_args, obs=_obs))
            $body
            _retn
        end
    end)

    @under_global M q
end


function _get_gg_func_body(::RuntimeFn{Args,Kwargs,Body}) where {Args,Kwargs,Body}
    Body
end

function _get_gg_func_body(ex)
    error(ex)
end

@generated function mkfun_call(_mc::MC, ::T, _cfg, _ctx) where {MC, T}
    _m = type2model(MC)
    M = getmodule(_m)

    _args = argvalstype(MC)
    _obs = obstype(MC)

    tilde = T.instance
    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(M, body, tilde, _args, _obs)

    q = MacroTools.flatten(@q function (_mc, _cfg, _ctx)
            local _retn
            _args = Soss.argvals(_mc)
            _obs = Soss.observations(_mc)
            _cfg = merge(_cfg, (args=_args, obs=_obs))
            $body
            _retn
        end)

    from_type(_get_gg_func_body(mk_function(M, q)))
end
