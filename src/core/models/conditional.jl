struct ConditionalModel{A,B,M,Argvals,Obs} <: AbstractModel{A,B,M,Argvals,Obs}
    model :: Model{A,B,M}
    argvals :: Argvals
    obs :: Obs
end

argvals(c::ConditionalModel) = c.argvals

Model(c::ConditionalModel) = c.model

ConditionalModel(m::Model) = ConditionalModel(m,NamedTuple(), NamedTuple())

(m::Model)(nt::NamedTuple) = ConditionalModel(m)(nt)

(cm::ConditionalModel)(nt::NamedTuple) = ConditionalModel(cm.model, merge(cm.argvals, nt), cm.obs)

(m::Model)(;argvals...)= m((;argvals...))

import Base

Base.:|(m::Model, nt::NamedTuple) = ConditionalModel(m) | nt

Base.:|(cm::ConditionalModel, nt::NamedTuple) = ConditionalModel(cm.model, cm.argvals, merge(cm.obs, nt))
