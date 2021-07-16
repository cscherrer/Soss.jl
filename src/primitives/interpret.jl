export interpret

function interpret(m::ASTModel{A,B,M}, _tilde, call=nothing) where {A,B,M}
    theModule = from_type(M)
    mk_function(theModule, _interpret(m.body, _tilde; call=call))
end

function _interpret(ast::Expr, _tilde, _ctx0, call=nothing)
    function branch(head, newargs)
        expr = Expr(head, newargs...)
        (head, newargs[1]) == (:call, :~) || return expr
        length(newargs) == 3 || return expr

        (_, x, d) = newargs
        :(($x, _ctx) = $_tilde(Val{$(QuoteNode(x))}(), $d, _ctx))
    end

    body = foldall(identity, branch)(ast)

    if !isnothing(call)
        body = callify(body; call=call)
    end

    quote
        _ctx = $_ctx0
        $(body.args...)
        _ctx
    end
end

function mkfun(f, M, _m, _args, _obs, tilde, ctx0, call)
    call = call.instance
    _m = type2model(_m)


    body = _m.body |> loadvals(_args, NamedTuple())
    body = _interpret(body, tilde, ctx0, call)

    body = f(body)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end



@inline function Base.rand(rng::AbstractRNG, m::ASTModel; call=nothing)
    return _rand(getmoduletypencoding(m), m, NamedTuple(), call)(rng)
end

@gg function _rand(M::Type{<:TypeLevel}, _m::ASTModel, _args, call)
    _obs = NamedTuple()
    function tilde(v::Val, d, ctx)
        x = rand(d)
        ctx = merge(ctx, NamedTuple{(unVal(v),)}((x,)))
        (x, ctx)
    end

    ctx0 = NamedTuple()

    f(ex) = quote
        function(_rng)
            $(ex.args...)
        end
    end

    mkfun(f, M, _m, _args, _obs, tilde, ctx0, call)
end

# @gg function _rand(M::Type{<:TypeLevel}, _m::ASTModel, _args::NamedTuple{()})
#     body = type2model(_m) |> sourceRand()
#     @under_global from_type(_unwrap_type(M)) @q let M
#         $body
#     end
# end
