
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

@inline function tilde_logdensity_def(v, d::AbstractModelFunction, cfg, ctx::NamedTuple, inargs, inobs)
    ℓ = ctx.ℓ
    x = getproperty(cfg, v)
    Δℓ = logdensity_def(d(cfg._args), x)
    ℓ += Δℓ
    merge(ctx, (ℓ=ℓ, Δℓ=Δℓ))
    (x, ctx, ℓ)
end


function MeasureBase.logdensity_def(c::ModelPosterior, x=NamedTuple())
    _logpdf(M, Model(c), argvals(c), observations(c), x)
end

export sourceLogdensityDef

sourceLogdensityDef(m::AbstractModel) = sourceLogdensityDef()(Model(m))

function sourceLogdensityDef()
    function(_m::DAGModel)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        # proc(_m, st :: Sample)     = :(_ℓ += logpdf($(st.rhs), $(st.x)))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            rhs = st.rhs
            @q begin
                _ℓ += Soss.logpdf($rhs, $x)
                $x = Soss.predict($rhs, $x)
            end
        end

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

# MeasureBase.logdensity_defd::Distribution, val, tr) = logpdf(d, val)


@gg function _logdensity_def(M::Type{<:TypeLevel}, _m::DAGModel, _args, _data, _pars)
    body = type2model(_m) |> sourceLogdensityDef() |> loadvals(_args, _data, _pars)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end
