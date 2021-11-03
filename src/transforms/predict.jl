export predict
using TupleVectors
using SampleChains

predict(args...; kwargs...) = predict(Random.GLOBAL_RNG, args...; kwargs...)

# TODO: Fix this hack
predict(d::AbstractMeasure, x) = x
predict(d::Dists.Distribution, x) = x
predict(d::AbstractModel, args...; kwargs...) = predict(Random.GLOBAL_RNG, d, args...; kwargs...)

@inline function predict(rng::AbstractRNG, m::AbstractModel, nt::NamedTuple{N}) where {N}
    pred = predictive(Model(m), N...)
    rand(rng, pred(merge(argvals(m), nt)))
end

predict(rng::AbstractRNG, m::AbstractModel; kwargs...) = predict(rng, m, (;kwargs...))


@inline function predict(rng::AbstractRNG, d::AbstractModel, nt::LazyMerge)
    predict(rng, d, convert(NamedTuple, nt))
end

function predict(rng::AbstractRNG, d::AbstractModel, post::AbstractVector{<:NamedTuple{N}}) where {N}
    m = Model(d)
    pred = predictive(m, N...)
    args = argvals(d)
    y1 = rand(rng, pred(merge(args,post[1])))
    n = length(post)
    v = TupleVectors.chainvec(y1, n)
    @inbounds for j in 2:n
        newargs = merge(args,post[j])
        v[j] = rand(rng, pred(newargs))
    end

    v
end

function predict(rng::AbstractRNG, d::ConditionalModel, post::MultiChain)
    [predict(rng, d, c) for c in getchains(post)]
end
