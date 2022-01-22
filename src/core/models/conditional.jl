struct ModelClosure{M,A} <: AbstractModel{A,B}
    model :: M
    argvals :: A
end

function Base.show(io::IO, cm::ModelClosure)
    println(io, "ModelClosure given")
    println(io, "    arguments    ", keys(argvals(cm)))
    println(io, "    observations ", keys(observations(cm)))
    println(io, Model(cm))
end

export argvals
argvals(c::ModelClosure) = c.argvals
argvals(c::ModelPosterior) = c.argvals
argvals(m::Model) = NamedTuple()

export observations
observations(c::ModelClosure) = c.obs

export observed
function observed(cm::ModelClosure{M,A,O}) where {M,A,O}
    keys(schema(Obs))
end

Model(c::ModelClosure) = c.model

ModelClosure(m::AbstractModel) = ModelClosure(m,NamedTuple(), NamedTuple())
Model(::Type{<:ModelPosterior{M,A,O}}) where {M,A,O} = type2model(Model{M,A,O})

ModelPosterior(m::Model) = ModelPosterior(m,NamedTuple(), NamedTuple())

(m::AbstractModel)(nt::NamedTuple) = ModelClosure(m)(nt)

(cm::ModelClosure)(nt::NamedTuple) = ModelClosure(cm.model, merge(cm.argvals, nt), cm.obs)

(m::AbstractModel)(;argvals...)= m((;argvals...))

(m::AbstractModel)(args...) = m(NamedTuple{Tuple(m.args)}(args...))
(m::Model)(args...) = m(NamedTuple{Tuple(m.args)}(args))

import Base

Base.:|(m::AbstractModel, nt::NamedTuple) = ModelClosure(m) | nt

Base.:|(cm::ModelClosure, nt::NamedTuple) = ModelClosure(cm.model, cm.argvals, merge(cm.obs, nt))
