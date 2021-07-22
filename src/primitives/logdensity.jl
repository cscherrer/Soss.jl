
export logdensity

using NestedTuples: lazymerge
import MeasureTheory


@inline function MeasureTheory.logdensity(post::ModelPosterior, par; cfg = NamedTuple(), ctx=(ℓ=0.0,), call=nothing)
    logdensity(post.closure, lazymerge(observations(post), par); cfg=cfg, ctx=ctx, call=call)
end

@inline function MeasureTheory.logdensity(mc::ModelClosure, data; cfg = NamedTuple(), ctx=(ℓ=0.0,), call=nothing)
    cfg = merge(cfg, data)
    f = mkfun(mc, tilde_logdensity, call)
    return f(cfg, ctx)
end

@inline function tilde_logdensity(v, d, cfg, ctx::NamedTuple, inargs, inobs)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity(d, x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end

@inline function tilde_logdensity(v, d::AbstractModelFunction, cfg, ctx::NamedTuple, inargs, inobs)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity(d(cfg._args), x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end

@testset "Nested models" begin
    m = @model begin
        params ~ @model begin
            p ~ Uniform()
            end
        obs = @model params begin
            x ~ Bernoulli(params.p)
            end
        data ~ obs(params=params)
    end

    @test logdensity(m(), rand(m())) isa Float64
end
