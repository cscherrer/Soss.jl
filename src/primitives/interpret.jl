export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(theModule, m.body, tilde, ctx0))
end

function _interpret(M, ast::Expr, _tilde, _args, _obs)
    myscope = Ref((bounds = Var[], freevars = Var[], bound_inits = Symbol[]))

    function go(ex)
        @match ex begin
            :($x ~ $d) => begin
                x = x.name
                qx = QuoteNode(x)
                xname = to_type(x)
                measure = to_type(d)
                varnames = Tuple(locals(d) ∩ myscope[].bound_inits)
                varvals = Expr(:tuple, varnames...)
                quote
                    ($x, _ctx, _retn) = let targs = Soss.TildeArgs($xname, $measure, NamedTuple{$varnames}($varvals))
                        $_tilde($qx, $d, _cfg, _ctx, targs)
                    end

                    _retn isa Soss.ReturnNow && return _retn.value
                end
            end

            Expr(:scoped, new_scope, ex) => begin
                myscope[] = new_scope
                go(ex)
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


@generated function mkfun_call(_mc::MC, ::T, _cfg, _ctx) where {MC, T}
    _m = type2model(MC)
    M = getmodule(_m)

    _args = argvalstype(MC)
    _obs = obstype(MC)

    tilde = T.instance
    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(M, body, tilde, _args, _obs)

    q = MacroTools.flatten(@q let M
            local _retn
            _args = Soss.argvals(_mc)
            _obs = Soss.observations(_mc)
            _cfg = merge(_cfg, (args=_args, obs=_obs))
            $body
            _retn
        end)

    xs = mk_expr(M, q)
    Base.show(xs)
    xs
    # @under_global M q
end