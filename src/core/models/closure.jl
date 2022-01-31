struct ModelClosure{M,A} <: AbstractConditionalModel{M,A,Nothing}
    model::M
    argvals::A
end

function Base.show(io::IO, mc::ModelClosure)
    println(io, "ModelClosure given")
    println(io, "    arguments    ", keys(argvals(mc)))
    println(io, "    observations ", keys(observations(mc)))
    println(io, model(mc))
end

export argvals
argvals(c::ModelClosure) = c.argvals

export observations
observations(c::ModelClosure) = NamedTuple()

export observed
function observed(mc::ModelClosure{M,A}) where {M,A}
    NamedTuple()
end

model(c::ModelClosure) = c.model

ModelClosure(m::AbstractModel) = ModelClosure(m,NamedTuple())

(m::AbstractModel)(nt::NamedTuple) = ModelClosure(m, nt)

(mc::ModelClosure)(nt::NamedTuple) = ModelClosure(model(mc), merge(mc.argvals, nt))

argvalstype(mc::ModelClosure{M,A}) where {M,A} = A
argvalstype(::Type{MC}) where {M,A,MC<:ModelClosure{M,A}} = A

obstype(::ModelClosure) = NamedTuple{(), Tuple{}}
obstype(::Type{<:ModelClosure}) = NamedTuple{(), Tuple{}}

type2model(::Type{MC}) where {M,MC<:ModelClosure{M}} = type2model(M)

import Base

Base.:|(m::ModelClosure, nt::NamedTuple) = ModelPosterior(m, nt)
