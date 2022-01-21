import SimplePosets
using SimpleGraphs: SimpleGraph, AbstractSimpleGraph, SimpleDigraph, eltype, NV, elist, in_neighbors, add_edges!, vertex2idx

export toposort
function toposort(m::DAGModel)
    names = toposort(poset(m).D)
    setdiff(names, arguments(m))
end

# Thanks to @CameronBieganek for this implementation:
# https://discourse.julialang.org/t/lightgraphs-jl-transition/69526/52?u=cscherrer
function toposort(g::SimpleDigraph{T}) where {T}
    g = deepcopy(g)
    order = T[]
    s = Symbol[v for v in vlist(g) if SimpleGraphs.in_deg(g, v) == 0]

    while !isempty(s)
        u = pop!(s)
        push!(order, u)

        for v in out_neighbors(g, u)
            SimpleGraphs.delete!(g, u, v)
            if SimpleGraphs.in_deg(g, v) == 0
                push!(s, v)
            end
        end
    end

    if SimpleGraphs.NE(g) > 0
        error("Graph contains cycles.")
    end

    order
end
