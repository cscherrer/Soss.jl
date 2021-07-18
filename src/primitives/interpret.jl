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
        :(($x, _ctx) = $_tilde(Val{$(QuoteNode(x))}(), $d, _ctx, _runtime_args))
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

    @under_global M @q let M
        function(_runtime_args)
            $body
        end
    end
end



@inline function Base.rand(rng::AbstractRNG, m::ASTModel; call=nothing)
    return _rand(m, NamedTuple(), call)(rng)
end

function tilde_rand(v::Val, d, ctx, rng)
    x = rand(rng, d)
    ctx = merge(ctx, NamedTuple{(unVal(v),)}((x,)))
    (x, ctx)
end

@gg function _rand(_m::ASTModel, _args, call)
    _obs = NamedTuple()
    ctx0 = NamedTuple()

    mkfun(_m, _args, _obs, tilde_rand, ctx0, call)
end
