export graph



@reexport using LightGraphs
@reexport using MetaGraphs
function graph(m::Model)
    vars = variables(m)
    g = MetaDiGraph(length(vars))
    for (n,v) in enumerate(vars)
        set_prop!(g, n, :name, v)
    end
    set_indexing_prop!(g, :name)
    postwalk(m.body) do x 
        if @capture(x,v_~d_) || @capture(x,v_⩪d_) || @capture(x,v_=d_)
            for rhs in findsubexprs(d,vars)
                add_edge!(g,(g[rhs,:name],g[v,:name]))
            end
        else x
        end
    end
    g
end


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
