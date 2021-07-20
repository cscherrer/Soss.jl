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

# @inline function Base.rand(rng::AbstractRNG, c::ModelClosure)
#     m = Model(c)
#     return _rand(getmoduletypencoding(m), m, argvals(c))(rng)
# end

@inline function Base.rand(m::ModelClosure; kwargs...) 
    rand(GLOBAL_RNG, m; kwargs...)
end

# @inline function Base.rand(rng::AbstractRNG, m::DAGModel)
#     return _rand(getmoduletypencoding(m), m, NamedTuple())(rng)
# end

# rand(m::DAGModel) = rand(GLOBAL_RNG, m)



# sourceRand(m::DAGModel) = sourceRand()(m)
# sourceRand(jd::ModelClosure) = sourceRand(jd.model)

# export sourceRand
# function sourceRand() 
#     function(_m::DAGModel)
#         proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
#         proc(_m, st::Sample)  = :($(st.x) = rand(_rng, $(st.rhs)))
#         proc(_m, st::Return)  = :(return $(st.rhs))
#         proc(_m, st::LineNumber) = nothing

#         vals = map(x -> Expr(:(=), x,x),parameters(_m)) 

#         wrap(kernel) = @q begin
#             _rng -> begin
#                 $kernel
#                 $(Expr(:tuple, vals...))
#             end
#         end

#         buildSource(_m, proc, wrap) |> MacroTools.flatten
#     end
# end

# @gg function _rand(M::Type{<:TypeLevel}, _m::DAGModel, _args)
#     body = type2model(_m) |> sourceRand() |> loadvals(_args, NamedTuple())
#     @under_global from_type(_unwrap_type(M)) @q let M
#         $body
#     end
# end

# @gg function _rand(M::Type{<:TypeLevel}, _m::DAGModel, _args::NamedTuple{()})
#     body = type2model(_m) |> sourceRand()
#     @under_global from_type(_unwrap_type(M)) @q let M
#         $body
#     end
# end


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

@inline function tilde_rand(v, d::AbstractModelFunction, cfg, ctx::NamedTuple)
    _args = get(cfg._args, v, NamedTuple())
    cfg = merge(cfg, (_args = _args,))
    tilde_rand(v, d(cfg._args), cfg, ctx)
end

@inline function tilde_rand(v, d::AbstractModelFunction, cfg, ctx::Dict)
    _args = get(cfg._args, v, Dict())
    cfg = merge(cfg, (_args = _args,))
    tilde_rand(v, d(cfg._args), cfg, ctx)
end


@inline function Base.rand(rng::AbstractRNG, mc::ModelClosure; cfg = NamedTuple(), ctx=NamedTuple(), call=nothing)
    cfg = merge(cfg, (rng=rng,))
    f = mkfun(mc, tilde_rand, call)
    return f(cfg, ctx)
end

@testset "rand" begin
    m = @model begin
        p ~ Uniform()
        x ~ Bernoulli(p)
    end

    @test rand(m(); ctx=()) isa Bool
    @test logdensity(m(), rand(m())) isa Float64
end
