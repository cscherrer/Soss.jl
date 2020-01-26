export Do

function Do(m::Model, xs::Symbol...)
    theModule = getmodule(m)
    newargs = (arguments(m) ∪ xs)

    m_init = Model(theModule, newargs, NamedTuple(), NamedTuple(), nothing)
    m = foldl(setdiff(parameters(m), xs); init=m_init) do m0,v
        merge(m0, Model(theModule, findStatement(m, v)))
    end
end


Do(m::Model; kwargs...) = Do(m,keys(kwargs)...)(;kwargs...)
