

export prune
function prune(m::Model, xs :: Symbol...)
    po = poset(m) #Creates a new SimplePoset, so no need to copy before mutating

    newvars = variables(m)

    for x in xs
        setdiff!(newvars, above(po,x))
        setdiff!(newvars, [x])
    end

    # Removes unused arguments, removes arguments from variable list.
    newargs = arguments(m) ∩ newvars
    setdiff!(newvars, newargs)

    theModule = getmodule(m)
    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(newvars; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end
