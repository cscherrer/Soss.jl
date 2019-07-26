using SimplePosets
using SimpleGraphs

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

export toposortvars
function toposortvars(m::Model)
    (g, _, names) = poset(unobserve(m)).D |> convert_simple
    unobs = [names[v] for v in Graphs.topological_sort_by_dfs(g)]
    obs = observed(m)
    vcat(unobs, obs)
end

export toposort 
function toposort(m::Model)
    modelvs = varName.(m.body)
    sortedvs = toposortvars(m)
    body = Statement[]
    for v in sortedvs
        for j in findall(isequal(v), modelvs)
            isnothing(j) || push!(body, m.body[j])
        end
    end
    Model(m.args, body)
end