using SimplePartitions: find_part
import SimpleGraphs

export parents
parents(g::SimpleDigraph, v) = g.NN[v] |> collect

export children
children(g::SimpleDigraph, v) = g.N[v] |> collect




function stochParents(m::Model, g::SimpleDigraph, v::Symbol)
    union([], [stochParents(m, g, findStatement(m,p)) for p in parents(g,v)]...)
end

stochParents(m::Model, g::SimpleDigraph, st::Sample) = [st.x]
stochParents(m::Model, g::SimpleDigraph, st::Assign) = stochParents(m, g, st.x)

stochParents(m::Model, g::SimpleDigraph, st::Bool) = []


####################

function stochChildren(m::Model, g::SimpleDigraph, v::Symbol)
    union([], [stochChildren(m, g, findStatement(m,p)) for p in children(g,v)]...)
end

stochChildren(m::Model, g::SimpleDigraph, st::Sample) = [st.x]
stochChildren(m::Model, g::SimpleDigraph, st::Assign) = stochChildren(m, g, st.x)

stochChildren(m::Model, g::SimpleDigraph, st::Bool) = []

########################

function stochPartners(m::Model, g::SimpleDigraph, v::Symbol)
    s = map(collect(stochChildren(m,g,v))) do x 
        stochParents(m,g,x) 
    end

    isempty(s) && return []

    setdiff(union(s...),[v]) |> collect
end

function markovBlanketVars(m::Model,v::Symbol)
    p = poset(m)
    g = digraph(m)

    args = union(stochParents(m,g,v), stochPartners(m,g,v))
    args_to_end = union([],map(arg -> above(p,arg), args)...)

    ys = stochChildren(m,g,v)
    start_to_ys = union(ys, map(y -> below(p,y), ys)...)
    
    body = intersect(args_to_end, start_to_ys)

    (args, body)
end

# markovBlanket(g,v) = [v] ∪ stochParents(g,v) ∪ stochChildren(g,v) ∪ stochPartners(g,v)

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

