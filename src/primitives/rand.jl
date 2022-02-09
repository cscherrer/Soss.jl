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

# @inline function Base.rand(rng::AbstractRNG, c::ModelPosterior{A,B,M}) where {A,B,M}
#     m =model(c)
#     return _rand(M, m, argvals(c))(rng)
# end

@inline function makeRand(rng::AbstractRNG, mc::ModelClosure; cfg = NamedTuple(), ctx=NamedTuple())
    cfg = merge(cfg, (rng=rng,))
    f = mkfun(mc, tilde_rand)
end


@inline function Base.rand(rng::AbstractRNG, mc::ModelClosure; cfg = NamedTuple(), ctx=NamedTuple())
    cfg = merge(cfg, (rng=rng,))
    f = mkfun(mc, tilde_rand)
    return f(cfg, ctx)
end

###############################################################################
# ctx::NamedTuple

@inline function tilde_rand(v, d, cfg, ctx::NamedTuple, targs::TildeArgs)
    x = rand(cfg.rng, d)
    ctx = merge(ctx, NamedTuple{(v,)}((x,)))
    (x, ctx, ctx)
end

# @inline function tilde_rand(v, d::AbstractConditionalModel, cfg, ctx::NamedTuple, targs::TildeArgs)
#     args = get(cfg.args, v, NamedTuple())
#     cfg = merge(cfg, (args = args,))
#     tilde_rand(v, d(cfg.args), cfg, ctx)
# end

###############################################################################
# ctx::Dict

@inline function tilde_rand(v, d, cfg, ctx::Dict, targs::TildeArgs)
    x = rand(cfg.rng, d)
    ctx[v] = x 
    (x, ctx, ctx)
end

@inline function tilde_rand(v, d::AbstractConditionalModel, cfg, ctx::Dict, targs::TildeArgs)
    args = get(cfg.args, v, Dict())
    cfg = merge(cfg, (args = args,))
    tilde_rand(v, d(cfg.args), cfg, ctx)
end

###############################################################################
# ctx::Tuple{}

@inline function tilde_rand(v, d, cfg, ctx::Tuple{}, targs::TildeArgs)
    x = rand(cfg.rng, d)
    (x, (), x)
end

@inline function tilde_rand(v, d::AbstractConditionalModel, cfg, ctx::Tuple{}, targs::TildeArgs)
    args = get(cfg.args, v, NamedTuple())
    cfg = merge(cfg, (args = args,))
    tilde_rand(v, d(cfg.args), cfg, ctx)
end

###############################################################################

