

export prune
function prune(m::Model, xs :: Symbol...; simplify = true)
    po = poset(m) #Creates a new SimplePoset, so no need to copy before mutating

    newvars = variables(m)

    for x in xs
        setdiff!(newvars, above(po,x))
        setdiff!(newvars, [x])
    end

    # Keep arguments in newvars
    newargs = arguments(m) ∩ newvars
    setdiff!(newvars, newargs)

    if simplify
        # keep arguments only if depended upon by newvars
        dependencies = mapfoldl(var -> below(po, var), vcat, newvars, init = Symbol[]) # mapfoldl needed since newvars can be empty
        newargs = dependencies ∩ newargs
    end

    theModule = getmodule(m)
    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(newvars; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end
