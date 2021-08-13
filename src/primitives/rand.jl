using GeneralizedGenerated
using Random: GLOBAL_RNG
using TupleVectors: chainvec

export rand
EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

function Base.rand(rng::AbstractRNG, d::ModelClosure, N::Int)
    r = chainvec(rand(rng, d), N)
    for j in 2:N
        @inbounds r[j] = rand(rng, d)
    end
    return r
end

Base.rand(d::ModelClosure, N::Int) = rand(GLOBAL_RNG, d, N)

@inline function Base.rand(m::ModelClosure; kwargs...) 
    rand(GLOBAL_RNG, m; kwargs...)
end

# @inline function Base.rand(rng::AbstractRNG, c::ConditionalModel{A,B,M}) where {A,B,M}
#     m = Model(c)
#     return _rand(M, m, argvals(c))(rng)
# end



@inline function Base.rand(rng::AbstractRNG, mc::ModelClosure; cfg = NamedTuple(), ctx=NamedTuple(), call=nothing)
    cfg = merge(cfg, (rng=rng,))
    f = mkfun(mc, tilde_rand, call)
    return f(cfg, ctx)
end

###############################################################################
# ctx::NamedTuple

@inline function tilde_rand(v, d, cfg, ctx::NamedTuple, inargs, inobs)
    x = rand(cfg.rng, d)
    ctx = merge(ctx, NamedTuple{(v,)}((x,)))
    (x, ctx, ctx)
end

@inline function tilde_rand(v, d::AbstractModelFunction, cfg, ctx::NamedTuple, inargs, inobs)
    _args = get(cfg._args, v, NamedTuple())
    cfg = merge(cfg, (_args = _args,))
    tilde_rand(v, d(cfg._args), cfg, ctx, inargs, inobs)
end

###############################################################################
# ctx::Dict

@inline function tilde_rand(v, d, cfg, ctx::Dict, inargs, inobs)
    x = rand(cfg.rng, d)
    ctx[v] = x 
    (x, ctx, ctx)
end

@inline function tilde_rand(v, d::AbstractModelFunction, cfg, ctx::Dict, inargs, inobs)
    _args = get(cfg._args, v, Dict())
    cfg = merge(cfg, (_args = _args,))
    tilde_rand(v, d(cfg._args), cfg, ctx, inargs, inobs)
end

###############################################################################
# ctx::Tuple{}

@inline function tilde_rand(v, d, cfg, ctx::Tuple{}, inargs, inobs)
    x = rand(cfg.rng, d)
    (x, (), x)
end

@inline function tilde_rand(v, d::AbstractModelFunction, cfg, ctx::Tuple{}, inargs, inobs)
    _args = get(cfg._args, v, NamedTuple())
    cfg = merge(cfg, (_args = _args,))
    tilde_rand(v, d(cfg._args), cfg, ctx, inargs, inobs)
end

###############################################################################
