struct ModelClosure{M,A}
    model::M
    argvals::A
end

function Base.show(io::IO, cm::ModelClosure)
    println(io, "ModelClosure given")
    println(io, "    arguments    ", keys(argvals(cm)))
    println(io, "    observations ", keys(observations(cm)))
    println(io, Model(cm))
end

export argvals
argvals(c::ModelClosure) = c.argvals

export observations
observations(c::ModelClosure) = c.obs

export observed
function observed(cm::ModelClosure{M,A}) where {M,A}
    NamedTuple()
end

Model(c::ModelClosure) = c.model

ModelClosure(m::AbstractModelFunction) = ModelClosure(m,NamedTuple())

(m::AbstractModelFunction)(nt::NamedTuple) = ModelClosure(m, nt)

(cm::ModelClosure)(nt::NamedTuple) = ModelClosure(cm.model, merge(cm.argvals, nt), cm.obs)


import Base

Base.:|(m::ModelClosure, nt::NamedTuple) = ModelPosterior(m, nt)
