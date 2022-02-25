export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(theModule, m.body, tilde, ctx0))
end

function _interpret(M, ast::Expr, _tilde, _args, _obs)
    function go(ex, scope=(bounds = Var[], freevars = Var[], bound_inits = Symbol[]))
        @match ex begin
            :(($x, $o) ~ $rhs) => begin
                varnames = Tuple(locals(o) ∪ locals(rhs))
                varvals = Expr(:tuple, varnames...)

                x = unsolve(x)
                o = unsolve(o)
                q = quote
                    _vars = NamedTuple{$varnames}($varvals)
                    @show _vars
                end

                # unsolved_lhs = unsolve(lhs)
                # x == unsolved_lhs && delete!(varnames, x)

                qx = QuoteNode(x)
                # X = to_type(unsolved_lhs)
                M = to_type(unsolve(rhs))

                push!(q.args, quote
                    if $o !== identity
                        _vars = merge(_vars, NamedTuple{($qx,)}(($x,)))
                    end
                end)
            
                push!(q.args, quote
                    ($x, _ctx, _retn) = $_tilde($qx, $o, $rhs, _cfg, _ctx, _vars)
                    _retn isa Soss.ReturnNow && return _retn.value
                end)

                q
            end

            Expr(:scoped, new_scope, ex) => begin
                go(ex, new_scope)
            end

            Expr(head, args...) => Expr(head, map(Base.Fix2(go, scope), args)...)
            
            x => x
        end
    end


    body = go(@q let 
            $(solve_scope(opticize(ast)))
    end) |> unsolve |> MacroTools.flatten

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

function mkfun_body(_mc::MC, ::T, _cfg, _ctx) where {MC, T}
    _m = type2model(MC)
    M = getmodule(_m)

    _args = argvalstype(MC)
    _obs = obstype(MC)

    tilde = T.instance
    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(M, body, tilde, _args, _obs)

    q = MacroTools.flatten(@q function ($_mc, $_cfg, $_ctx)
            local _retn
            _args = Soss.argvals($_mc)
            _obs = Soss.observations($_mc)
            _cfg = merge(_cfg, (args=_args, obs=_obs))
            $body
            _retn
        end)

    q
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
