export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(m.body, tilde, ctx0))
end

function _interpret(ast::Expr, _tilde, pars, _args, _obs)
    function gotos(pars)
        q = quote end
        for par in pars
            qpar = QuoteNode(par)
            par_label = QuoteNode(Symbol(Sample_, $qpar))
            push!(q.args, 
            quote
                _next_command = _driver()
                $(Expr(:symbolicgoto, $par_label))

            end
        end
        return q
    end

    function new_ast(ex)
        @match ex begin
            :($(x::Symbol) ~ $d) => begin
                qx = QuoteNode(x)
                inargs = Val(x ∈ getntkeys(_args))
                inobs = Val(x ∈ getntkeys(_obs))
                quote
                    :($(Expr(:symboliclabel, Symbol(Sample_, $qx))))
                    ($x, _ctx, _retn) = $_tilde($qx, $d, _cfg, _ctx, $inargs, $inobs)
                end
            end

            Expr(head, args...) => Expr(head, map(new_ast, args)...)
            
            x => x
        end
    end

    body = new_ast(ast)

    body
end

@gg function mkfun(_mc::MC, ::T, ::C) where {MC, T, C}
    _m = type2model(MC)
    M = getmodule(_m)

    _args = argvalstype(MC)
    _obs = obstype(MC)

    tilde = T.instance
    call = C.instance
    
    pars = parameters(_m)

    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(body, tilde, pars, _args, _obs)

    q = (@q let M
        @inline function(_cfg, _ctx)
            local _retn
            _args = Soss.argvals(_mc)
            _obs = Soss.observations(_mc)
            _cfg = merge(_cfg, (_args=_args, _obs=_obs))
            $body
            _retn
        end
    end) |> MacroTools.flatten
end
