export predict

function predict(d::JointDistribution, post::Vector{NamedTuple{N,T}}) where {N,T}
    args = d.args
    m = d.model
    pred = predictive(m, keys(post[1])...)
    map(nt -> rand(pred(merge(args,nt))), post)
end

function predict(m::Model, post::Vector{NamedTuple{N,T}}) where {N,T}
    pred = predictive(m, keys(post[1])...)
    map(nt -> rand(pred(nt)), post)
end


# TODO: These don't yet work properly t on particles

function predict(d::JointDistribution, post::NamedTuple{N,T}) where {N,T}
    args = d.args
    m = d.model
    pred = predictive(m, keys(post)...)
    rand(pred(merge(args,post)))
end

function predict(m::Model, post::NamedTuple{N,T}) where {N,T}
    pred = predictive(m, keys(post)...)
    rand(pred(post))
end

predict(m::Model; kwargs...) = predict(m,(;kwargs...))
