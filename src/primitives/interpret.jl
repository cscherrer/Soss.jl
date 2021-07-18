export interpret

function interpret(m::ASTModel{A,B,M}, tilde, ctx0, call=nothing) where {A,B,M}
    interp = _interpret(m.body, tilde, ctx0, call)
end

function _interpret(ast::Expr, _tilde, _ctx, call=nothing)
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

    body
end

function mkfun(_m, _args, _obs, tilde, call)
    call = call.instance
    _m = type2model(_m)
    M = getmodule(_m)

    body = _m.body |> loadvals(_args, NamedTuple())
    body = _interpret(body, tilde, call)

    @under_global M @q let M
        function(_cfg, _ctx)
            $body
            _ctx
        end
    end
end



@inline function Base.rand(rng::AbstractRNG, m::ASTModel; cfg = NamedTuple(), ctx=NamedTuple(), call=nothing)
    cfg = merge(cfg, (rng=rng,))
    return _rand(m, NamedTuple(), call)(cfg, ctx)
end

function tilde_rand(v::Val, d, cfg, ctx)
    rng = cfg.rng
    x = rand(rng, d)
    ctx = merge(ctx, NamedTuple{(unVal(v),)}((x,)))
    (x, ctx)
end

@gg function _rand(_m::ASTModel, _args, call)
    _obs = NamedTuple()

    mkfun(_m, _args, _obs, tilde_rand, call)
end


export rand2

@inline function rand2(rng::AbstractRNG, m::ASTModel; call=nothing)
    return _rand2(m, NamedTuple(), call)(rng)
end

function tilde_rand2(v::Val, d, ctx, rng)
    x = rand(rng, d)
    (x, ())
end

@gg function _rand2(_m::ASTModel, _args, call)
    _obs = NamedTuple()
    ctx0 = NamedTuple()

    mkfun(_m, _args, _obs, tilde_rand2, ctx0, call)
end
