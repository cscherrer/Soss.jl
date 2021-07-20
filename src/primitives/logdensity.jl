
export logdensity

using NestedTuples: lazymerge
import MeasureTheory

# function MeasureTheory.logdensity(c::ModelClosure{M,A}, x=NamedTuple()) where {M,A}
#     _logdensity(M, Model(c), argvals(c), observations(c), x)
# end

# function MeasureTheory.logdensity(c::ModelPosterior{M,A,O}, x=NamedTuple()) where {M,A,O}
#     _logdensity(M, Model(c), argvals(c), observations(c), x)
# end

# export sourceLogdensity

# sourceLogdensity(m::AbstractModelFunction) = sourceLogdensity()(Model(m))

# function sourceLogdensity()
#     function(_m::DAGModel)
#         proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
#         # proc(_m, st :: Sample)     = :(_ℓ += logdensity($(st.rhs), $(st.x)))
#         proc(_m, st :: Return)     = nothing
#         proc(_m, st :: LineNumber) = nothing
#         function proc(_m, st :: Sample)
#             x = st.x
#             rhs = st.rhs
#             @q begin
#                 _ℓ += Soss.logdensity($rhs, $x)
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

# # MeasureTheory.logdensity(d::Distribution, val, tr) = logpdf(d, val)


# @gg function _logdensity(M::Type{<:TypeLevel}, _m::DAGModel, _args, _data, _pars)
#     body = type2model(_m) |> sourceLogdensity() |> loadvals(_args, _data, _pars)
#     @under_global from_type(_unwrap_type(M)) @q let M
#         $body
#     end
# end

@inline function MeasureTheory.logdensity(post::ModelPosterior, par; cfg = NamedTuple(), ctx=(ℓ=0.0,), call=nothing)
    logdensity(post.closure, lazymerge(observations(post), par); cfg=cfg, ctx=ctx, call=call)
end

@inline function MeasureTheory.logdensity(mc::ModelClosure, data; cfg = NamedTuple(), ctx=(ℓ=0.0,), call=nothing)
    cfg = merge(cfg, data)
    f = mkfun(mc, tilde_logdensity, call)
    return f(cfg, ctx)
end

@inline function tilde_logdensity(v, d, cfg, ctx::NamedTuple)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity(d, x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end

@inline function tilde_logdensity(v, d::AbstractModelFunction, cfg, ctx::NamedTuple)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity(d(cfg._args), x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end
