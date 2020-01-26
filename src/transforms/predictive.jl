using SimplePartitions: find_part
import SimpleGraphs



function Base.convert(::Type{SimpleGraph}, d::SimpleDigraph)
    g = SimpleGraph{Symbol}()
    add_edges!(g, elist(d))
    g
end

# Type piracy, this should really go in SimpleGraphs
# OTOH there's not anything else this could really mean
SimpleGraphs.components(g::SimpleDigraph) = SimpleGraphs.components(convert(SimpleGraph, g))

export predictive
function predictive(m::Model, x :: Symbol)
    g = digraph(m) #Creates a new SimpleDigraph, so no need to copy before mutating

    for xparent ∈ in_neighbors(g, x)
        delete!(g, xparent, x)
    end

    # Find the strongly connected component containing x
    part = find_part(SimpleGraphs.components(g), x) |> union

    newargs = (arguments(m) ∪ [x]) ∩ part
    setdiff!(part, newargs)

    theModule = getmodule(m)
    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(part; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end

predictive(m::Model, x::Symbol, xs...) = predictive(predictive(m,x), xs...)


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