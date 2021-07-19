export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0, call=nothing) where {A,B,M}
    theModule = getmodule(m)
    mk_function(theModule, _interpret(m.body, tilde, ctx0; call=call))
end

function _interpret(ast::Expr, _tilde, _ctx0, call=nothing)
    function branch(head, newargs)
        expr = Expr(head, newargs...)
        (head, newargs[1]) == (:call, :~) || return expr
        length(newargs) == 3 || return expr

        (_, x, d) = newargs
        :(($x, _ctx) = $_tilde(Val{$(QuoteNode(x))}(), $d, _cfg, _ctx))
    end

    body = foldall(identity, branch)(ast)

    if !isnothing(call)
        body = callify(body; call=call)
    end

    quote
        _ctx = $_ctx0
        $body
        _ctx
    end
end

function mkfun(_m, _args, _obs, tilde, ctx0, call)
    call = call.instance
    _m = type2model(_m)
    M = getmodule(_m)

    body = _m.body |> loadvals(_args, NamedTuple())
    body = _interpret(body, tilde, ctx0, call)

    q = (@q let M
        function(_cfg, _ctx)
            $body
        end
    end) |> MacroTools.flatten


function tilde_rand(v, d, cfg, ctx::NamedTuple)
    x = rand(cfg.rng, d)
    ctx = merge(ctx, NamedTuple{(unVal(v),)}((x,)))
    (x, ctx)
end

function tilde_rand(v, d, cfg, ctx::Dict)
    x = rand(cfg.rng, d)
    ctx[unVal(v)] = x 
    (x, ctx)
end

function tilde_rand(v, d, cfg, ctx::Tuple{})
    x = rand(cfg.rng, d)
    (x, ())
end

@inline function rand(rng::AbstractRNG, cm::ModelClosure; cfg = NamedTuple(), ctx=NamedTuple(), call=nothing)
    cfg = merge(cfg, (rng=rng,))
    args = argvals(cm)
    obs = NamedTuple()
    m = Model(cm)
    f = mkfun(m, args, obs, tilde_rand, call)
    return f(cfg, ctx)
end

@inline function rand(rng::AbstractRNG, m::ASTModel; cfg = NamedTuple(), ctx=NamedTuple(), call=nothing)
    cfg = merge(cfg, (rng=rng,))
    args = NamedTuple()
    obs = NamedTuple()
    f = mkfun(m, args, obs, tilde_rand, call)
    return f(cfg, ctx)
end
