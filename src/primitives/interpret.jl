export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(m.body, tilde, ctx0))
end

# abstract type Maybe{T} end 


function _interpret(ast::Expr, _tilde, _args, _obs)
    function go(ex)
        @match ex begin
            :($x ~ $d) => begin
                qx = QuoteNode(x)
                xname = to_type(x)
                measure = to_type(d)
                inargs = static(x ∈ getntkeys(_args))
                inobs = static(x ∈ getntkeys(_obs))
                quote
                    # _x_oldval = ifelse($(Expr(:isdefined, $qx)), Just($x), None())
                    _x_oldval = nothing
                    _targs = TildeArgs(_ctx, _cfg, _x_oldval, _vars, $inargs, $inobs)
                    ($x, _ctx, _retn) = $_tilde($xname, $measure, _targs)
                end
            end

            Expr(head, args...) => Expr(head, map(go, args)...)
            
            x => x
        end
    end

    body = go(@q let 
            $ast
    end)
    

    body
end

@gg function mkfun(_mc::MC, ::T) where {MC, T}
    _m = type2model(MC)
    M = getmodule(_m)

    _args = argvalstype(MC)
    _obs = obstype(MC)

    tilde = T.instance
     
    body = _m.body |> loadvals(_args, _obs)
    body = _interpret(body, tilde, _args, _obs)

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
end
