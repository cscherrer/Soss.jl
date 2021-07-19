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
        :(($x, _ctx, _retn) = $_tilde($(QuoteNode(x)), $d, _cfg, _ctx))
    end

    body = foldall(identity, branch)(ast)

    if !isnothing(call)
        body = callify(body; call=call)
    end

    body
end

@gg function mkfun(_m, _args, _obs, tilde, call)
    tilde = tilde.instance
    call = call.instance

    _m = type2model(_m)
    M = getmodule(_m)

    body = _m.body |> loadvals(_args, NamedTuple())
    body = _interpret(body, tilde, call)

    q = (@q let M
        function(_cfg, _ctx)
            $body
            _retn
        end
    end) |> MacroTools.flatten
end

@inline function tilde_rand(v, d, cfg, ctx::NamedTuple)
    x = rand(cfg.rng, d)
    ctx = merge(ctx, NamedTuple{(v,)}((x,)))
    (x, ctx, ctx)
end

@inline function tilde_rand(v, d, cfg, ctx::Dict)
    x = rand(cfg.rng, d)
    ctx[v] = x 
    (x, ctx, ctx)
end

@inline function tilde_rand(v, d, cfg, ctx::Tuple{})
    x = rand(cfg.rng, d)
    (x, (), x)
end

@inline function rand(rng::AbstractRNG, cm::ModelClosure; cfg = NamedTuple(), ctx=NamedTuple(), call=nothing)
    cfg = merge(cfg, (rng=rng,))
    args = argvals(cm)
    obs = NamedTuple()
    m = Model(cm)
    f = mkfun(m, args, obs, tilde_rand, call)
    return f(cfg, ctx)
end
