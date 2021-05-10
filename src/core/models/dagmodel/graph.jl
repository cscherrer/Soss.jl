export graph



@reexport using LightGraphs
@reexport using MetaGraphs
function graph(m::DAGModel)
    vars = variables(m)
    g = MetaDiGraph(length(vars))
    for (n,v) in enumerate(vars)
        set_prop!(g, n, :name, v)
    end
    set_indexing_prop!(g, :name)

    for (v, v_parents) in dependencies(m)
        for p in v_parents
            add_edge!(g, (g[p,:name],g[v,:name]))
        end
    end
    g
end

export graphEdges
function graphEdges(m::DAGModel)
    g = graph(m)
    [(g[e.src,:name] => g[e.dst,:name]) for e in edges(g)]
end

# TODO: order statements using topological_sort_by_dfs(graph(m))

# EXAMPLE

# julia> g = graph(lda)
# {10, 14} directed Int64 metagraph with Float64 weights defined by :weight (default weight 1.0)

# julia> [(g[e.src,:name] => g[e.dst,:name]) for e in edges(g)]
# 14-element Array{Pair{Symbol,Symbol},1}:
#  :w => :N
#  :w => :M
#  :w => :z
#  :w => :β
#  :M => :N
#  :z => :N
#  :z => :M
#  :z => :θ
#  :β => :K
#  :β => :V
#  :β => :η
#  :θ => :α
#  :θ => :M
#  :θ => :K
