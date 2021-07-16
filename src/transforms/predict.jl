export predict
using TupleVectors

function predict(d::ConditionalModel, post::Vector{NamedTuple{N,T}}) where {N,T}
    args = argvals(d)
    m = d.model
    pred = predictive(m, keys(post[1])...)
    map(nt -> rand(pred(merge(args,nt))), post)
end

function predict(m::Model, post::Vector{NamedTuple{N,T}}) where {N,T}
    pred = predictive(m, keys(post[1])...)
    map(nt -> rand(pred(nt)), post)
end


# TODO: These don't yet work properly t on particles

function predict(d::ConditionalModel, post::NamedTuple{N,T}) where {N,T}
    args = argvals(d)
    m = Model(d)
    pred = predictive(m, keys(post)...)
    rand(pred(merge(args,post)))
end

function predict(m::Model, post::NamedTuple{N,T}) where {N,T}
    pred = predictive(m, keys(post)...)
    rand(pred(post))
end

predict(m::Model; kwargs...) = predict(m,(;kwargs...))

predict(d,x) = x

predict(d::ConditionalModel, post) = predict(Random.GLOBAL_RNG, d, post)

function predict(rng::AbstractRNG, d::ConditionalModel, post::AbstractVector{<:NamedTuple{N}}) where {N}
    m = Model(d)
    pred = predictive(m, N...)
    args = argvals(d)
    y1 = rand(rng, pred(merge(args,post[1])))
    n = length(post)
    v = TupleVectors.chainvec(y1, n)
    for j in 2:n
        v[j] = rand(rng, pred(merge(args,post[j])))
    end

    v
end

using SampleChains

function predict(rng::AbstractRNG, d::ConditionalModel, post::MultiChain)
    [predict(rng, d, c) for c in getchains(post)]
end
