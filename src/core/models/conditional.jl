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

export observations
observations(c::ModelClosure) = c.obs

export observed
function observed(cm::ModelClosure{M,A,O}) where {M,A,O}
    keys(schema(Obs))
end

Model(c::ModelClosure) = c.model

ModelClosure(m::AbstractModelFunction) = ModelClosure(m,NamedTuple(), NamedTuple())

(m::AbstractModelFunction)(nt::NamedTuple) = ModelClosure(m)(nt)

(cm::ModelClosure)(nt::NamedTuple) = ModelClosure(cm.model, merge(cm.argvals, nt), cm.obs)

(m::AbstractModelFunction)(;argvals...)= m((;argvals...))

(m::AbstractModelFunction)(args...) = m(NamedTuple{Tuple(m.args)}(args...))

import Base

Base.:|(m::AbstractModelFunction, nt::NamedTuple) = ModelClosure(m) | nt

Base.:|(cm::ModelClosure, nt::NamedTuple) = ModelClosure(cm.model, cm.argvals, merge(cm.obs, nt))
