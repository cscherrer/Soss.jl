struct ModelClosure{M,A,O} <: AbstractModelFunction{A,B}
    model :: M
    argvals :: A
    obs :: O
end

function Base.show(io::IO, cm::ModelClosure)
    println(io, "ModelClosure given")
    println(io, "    arguments    ", keys(argvals(cm)))
    println(io, "    observations ", keys(observations(cm)))
    println(io, Model(cm))
end

export argvals
argvals(c::ModelClosure) = c.argvals
argvals(c::ConditionalModel) = c.argvals
argvals(m::Model) = NamedTuple()

export observations
observations(c::ModelClosure) = c.obs

export observed
function observed(cm::ModelClosure{M,A,O}) where {M,A,O}
    keys(schema(Obs))
end

Model(c::ModelClosure) = c.model

ModelClosure(m::AbstractModelFunction) = ModelClosure(m,NamedTuple(), NamedTuple())
Model(::Type{<:ConditionalModel{A,B,M}}) where {A,B,M} = type2model(Model{A,B,M})

ConditionalModel(m::Model) = ConditionalModel(m,NamedTuple(), NamedTuple())

(m::AbstractModelFunction)(nt::NamedTuple) = ModelClosure(m)(nt)

(cm::ModelClosure)(nt::NamedTuple) = ModelClosure(cm.model, merge(cm.argvals, nt), cm.obs)

(m::AbstractModelFunction)(;argvals...)= m((;argvals...))

(m::AbstractModelFunction)(args...) = m(NamedTuple{Tuple(m.args)}(args...))
(m::Model)(args...) = m(NamedTuple{Tuple(m.args)}(args))

import Base

Base.:|(m::AbstractModelFunction, nt::NamedTuple) = ModelClosure(m) | nt

Base.:|(cm::ModelClosure, nt::NamedTuple) = ModelClosure(cm.model, cm.argvals, merge(cm.obs, nt))
