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
observations(c::ModelClosure) = NamedTuple()

export observed
function observed(cm::ModelClosure{M,A}) where {M,A}
    NamedTuple()
end

Model(c::ModelClosure) = c.model

ModelClosure(m::AbstractModelFunction) = ModelClosure(m,NamedTuple())

(m::AbstractModelFunction)(nt::NamedTuple) = ModelClosure(m, nt)

(cm::ModelClosure)(nt::NamedTuple) = ModelClosure(cm.model, merge(cm.argvals, nt), cm.obs)

argvalstype(mc::ModelClosure{M,A}) where {M,A} = A
argvalstype(::Type{MC}) where {M,A,MC<:ModelClosure{M,A}} = A

obstype(::ModelClosure) = NamedTuple{(), Tuple{}}
obstype(::Type{<:ModelClosure}) = NamedTuple{(), Tuple{}}

type2model(::Type{MC}) where {M,A,MC<:ModelClosure{M,A}} = type2model(M)

import Base

Base.:|(m::ModelClosure, nt::NamedTuple) = ModelPosterior(m, nt)
