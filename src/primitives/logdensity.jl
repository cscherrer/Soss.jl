
export logdensityof

using NestedTuples: lazymerge
import MeasureTheory


@inline function MeasureBase.logdensity_def(post::ModelPosterior, par; cfg = NamedTuple(), ctx=(ℓ=0.0,), call=nothing)
    logdensity_def(post.closure, lazymerge(observations(post), par); cfg=cfg, ctx=ctx, call=call)
end

@inline function MeasureBase.logdensity_def(mc::ModelClosure, data; cfg = NamedTuple(), ctx=(ℓ=0.0,), call=nothing)
    cfg = merge(cfg, data)
    f = mkfun(mc, tilde_logdensity, call)
    return f(cfg, ctx)
end

@inline function tilde_logdensity_def(v, d, cfg, ctx::NamedTuple, inargs, inobs)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity_def(d, x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end

@inline function tilde_logdensity_def(v, d::AbstractModel, cfg, ctx::NamedTuple, inargs, inobs)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity_def(d(cfg._args), x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end

export sourceLogdensityOf

sourceLogdensityOf(m::AbstractModel) = sourceLogdensityOf()(Model(m))

# function sourceLogdensityOf()
#     function(_m::DAGModel)
#         proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
#         # proc(_m, st :: Sample)     = :(_ℓ += logpdf($(st.rhs), $(st.x)))
#         proc(_m, st :: Return)     = nothing
#         proc(_m, st :: LineNumber) = nothing
#         function proc(_m, st :: Sample)
#             x = st.x
#             rhs = st.rhs
#             @q begin
#                 _ℓ += Soss.logdensityof($rhs, $x)
#                 $x = Soss.predict($rhs, $x)
#             end
#         end

#         wrap(kernel) = @q begin
#             _ℓ = 0.0
#             $kernel
#             return _ℓ
#         end

#         buildSource(_m, proc, wrap) |> MacroTools.flatten
#     end
# end

# # MeasureBase.logdensity_defd::Distribution, val, tr) = logpdf(d, val)


# @gg function _logdensityof(M::Type{<:TypeLevel}, _m::DAGModel, _args, _data, _pars)
#     body = type2model(_m) |> sourceLogdensityOf() |> loadvals(_args, _data, _pars)
#     @under_global from_type(_unwrap_type(M)) @q let M
#         $body
#     end
# end

using Accessors

@inline function logdensityof(cm::AbstractConditionalModel, pars::NamedTuple)
    # TODO: Check insupport
    dynamic(unsafe_logdensityof(cm, pars))
end

@inline function MeasureBase.unsafe_logdensityof(cm::AbstractConditionalModel, pars::NamedTuple; cfg = NamedTuple(), ctx=NamedTuple())
    cfg = merge(cfg, (pars=pars,))
    ctx = merge(ctx, (ℓ = partialstatic(0.0),))
    f = mkfun(cm, tilde_unsafe_logdensityof)
    return f(cfg, ctx)
end

@inline function tilde_unsafe_logdensityof(v, d, cfg, ctx::NamedTuple, tildeargs) 
    x = getproperty(lazymerge(cfg.args, cfg.obs, cfg.pars), v)
    @reset ctx.ℓ += MeasureBase.unsafe_logdensityof(d, x)
    (x, ctx, ctx.ℓ)
end
