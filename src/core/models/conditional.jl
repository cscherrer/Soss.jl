struct ConditionalModel{A,B,M,Argvals,Obs} <: AbstractModel{A,B,M,Argvals,Obs}
    model :: Model{A,B,M}
    argvals :: Argvals
    obs :: Obs
end

function Base.show(io::IO, cm::ConditionalModel)
    println(io, "ConditionalModel given")
    println(io, "    arguments    ", keys(argvals(cm)))
    println(io, "    observations ", keys(obs(cm)))
    println(io, Model(cm))
end

export argvals
argvals(c::ConditionalModel) = c.argvals

export obs
obs(c::ConditionalModel) = c.obs

Model(c::ConditionalModel) = c.model

ConditionalModel(m::Model) = ConditionalModel(m,NamedTuple(), NamedTuple())

(m::Model)(nt::NamedTuple) = ConditionalModel(m)(nt)

(cm::ConditionalModel)(nt::NamedTuple) = ConditionalModel(cm.model, merge(cm.argvals, nt), cm.obs)

(m::Model)(;argvals...)= m((;argvals...))

import Base

Base.:|(m::Model, nt::NamedTuple) = ConditionalModel(m) | nt

Base.:|(cm::ConditionalModel, nt::NamedTuple) = ConditionalModel(cm.model, cm.argvals, merge(cm.obs, nt))
