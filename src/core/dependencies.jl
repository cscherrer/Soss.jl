

function graph(T, m::DAGModel)
    g = T()

    mvars = variables(m)
    for v in mvars
        SimplePosets.add!(g, v)
    end

    for (v, expr) in pairs(m.vals)
        for p in variables(expr) ∩ variables(m)
            SimplePosets.add!(g, p, v)
        end
    end

    for (v, expr) in pairs(m.dists)
        for p in variables(expr) ∩ variables(m)
            SimplePosets.add!(g, p, v)
        end
    end

    g
end

export digraph
digraph(m::DAGModel) = graph(SimpleDigraph{Symbol}, m)

export poset
poset(m::DAGModel) = graph(SimplePoset{Symbol}, m)
