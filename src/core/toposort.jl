using SimplePosets
using SimpleGraphs: SimpleGraph, AbstractSimpleGraph, SimpleDigraph, vertex_type, NV, elist, in_neighbors, add_edges!

import Graphs
import Graphs.simple_graph, Graphs.add_edge!, Graphs.topological_sort_by_dfs
export convert_simple

# From https://github.com/scheinerman/SimpleGraphs.jl/blob/1396758729f95912d7f245f9c70957f4993be417/src/simple_converters.jl
function convert_simple(G::AbstractSimpleGraph)
    T = vertex_type(G)
    n = NV(G)
    has_dir = isa(G,SimpleDigraph)


    d = SimpleGraphs.vertex2idx(G)
    dinv = Dict{Int,T}()
    for k in keys(d)
        v = d[k]
        dinv[v] = k
    end

    H = simple_graph(n,is_directed=has_dir)

    EE = elist(G)
    for e in EE
        u = d[e[1]]
        v = d[e[2]]
        add_edge!(H,u,v)
    end
    return (H,d,dinv)
end

export toposort
function toposort(m::Model)
    (g, _, names) = poset(m).D |> convert_simple
    setdiff(map(v -> names[v], Graphs.topological_sort_by_dfs(g)), arguments(m))
end
