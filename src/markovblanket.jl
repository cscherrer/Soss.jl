using SimplePartitions: find_part
import SimpleGraphs

export parents
parents(g::SimpleDigraph, v) = g.NN[v] |> collect

export children
children(g::SimpleDigraph, v) = g.N[v] |> collect

export partners
function partners(g::SimpleDigraph, v)
    s = map(collect(children(g,v))) do x 
        parents(g,x) 
    end

    isempty(s) && return []

    setdiff(union(s...),[v]) |> collect
end

markovBlanket(g,v) = [v] ∪ parents(g,v) ∪ children(g,v) ∪ partners(g,v)

# function Base.convert(::Type{SimpleGraph}, d::SimpleDigraph)
#     g = SimpleGraph{Symbol}()
#     add_edges!(g, elist(d))
#     g
# end

# # Type piracy, this should really go in SimpleGraphs
# # OTOH there's not anything else this could really mean
# SimpleGraphs.components(g::SimpleDigraph) = SimpleGraphs.components(convert(SimpleGraph, g))

export markovBlanket
function markovBlanket(m::Model, x :: Symbol)
    g = digraph(m) #Creates a new SimpleDigraph, so no need to copy before mutating


    # Find the strongly connected component containing x
    # part = find_part(SimpleGraphs.components(g), x) |> union

    # newargs = (arguments(m) ∪ [x]) ∩ part
    # setdiff!(part, newargs)

    newargs = parents(g,x) ∪ partners(g,x)

    m_init = Model(newargs, NamedTuple(), NamedTuple(), nothing)
    m_init = merge(m_init, Model(findStatement(m,x)))
    m = foldl(children(g,x); init= m_init) do m0,v
        merge(m0, Model(findStatement(m, v)))
    end
    m = merge(m, Model(findStatement(m,x)))
    
end

