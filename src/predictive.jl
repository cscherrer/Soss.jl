using SimplePartitions
using SimpleGraphs



function Base.convert(::Type{SimpleGraph}, d::SimpleDigraph)
    g = SimpleGraph{Symbol}()
    add_edges!(g, elist(d))
    g
end

# Type piracy, this should really go in SimpleGraphs
# OTOH there's not anything else this could really mean
SimpleGraphs.components(g::SimpleDigraph) = components(convert(SimpleGraph, g))

export predictive
function predictive(m::Model, x :: Symbol)
    g = digraph(m) #Creates a new SimpleDigraph, so no need to copy before mutating

    for xparent ∈ in_neighbors(g, x)
        delete!(g, xparent, x)
    end

    # Find the strongly connected component containing x
    part = find_part(SimpleGraphs.components(g), x) |> union

    newargs = arguments(m) ∪ [x]
    setdiff!(part, newargs)


    m_init = Model(newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(part; init=m_init) do m0,v
        merge(m0, Model(findStatement(m, v)))
    end
end

