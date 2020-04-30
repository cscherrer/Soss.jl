export prior

function prior(m::Model, xs...)
    po = poset(m) #Creates a new SimplePoset, so no need to copy before mutating

    newvars = collect(xs)

    for x in xs
        append!(newvars, below(po,x))
    end

    newargs = arguments(m) ∩ newvars
    setdiff!(newvars, newargs)

    theModule = getmodule(m)
    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(newvars; init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end
