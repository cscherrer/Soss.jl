using JuliaVariables
using MLStyle
import MacroTools

unwrap_scoped(ex) = @match ex begin
    Expr(:scoped, _, a) => unwrap_scoped(a)
    Expr(head, args...) => Expr(head, map(unwrap_scoped, args)...)
    a => a
end

globals(s::Symbol) = [s]

function globals(ex::Expr)
    branch(head, newargs) = union(newargs...)

    function leaf(v::JuliaVariables.Var)
        v.is_global ? [v.name] : Symbol[]
    end

    leaf(x) = []

    solved_ex = unwrap_scoped(solve_from_local!(simplify_ex(ex)))

    return foldall(leaf, branch)(solved_ex)
end


function graph(T, m::DAGModel)
    g = T()

    mvars = variables(m)
    for v in mvars
        SimplePosets.add!(g, v)
    end

    for (v, expr) in pairs(m.vals)
        for p in globals(expr) ∩ variables(m)
            SimplePosets.add!(g, p, v)
        end
    end

    for (v, expr) in pairs(m.dists)
        for p in globals(expr) ∩ variables(m)
            SimplePosets.add!(g, p, v)
        end
    end

    g
end

export digraph
digraph(m::DAGModel) = graph(SimpleDigraph{Symbol}, m)

export poset
poset(m::DAGModel) = graph(SimplePoset{Symbol}, m)
