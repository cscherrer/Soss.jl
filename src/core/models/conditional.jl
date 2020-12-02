struct ConditionalModel{A,B,M,Args,Obs} <: AbstractModel{A,B,M,Args,Obs}
    model :: Model{A,B,M}
    args :: Args
    obs :: Obs
end

Model(c::ConditionalModel) = c.model

ConditionalModel(m::Model) = ConditionalModel(m,NamedTuple(), NamedTuple())

(m::Model)(nt::NamedTuple) = ConditionalModel(m)(nt)

(cm::ConditionalModel)(nt::NamedTuple) = ConditionalModel(cm.model, merge(cm.args, nt), cm.obs)

(m::Model)(;args...)= m((;args...))

import Base

Base.:|(m::Model, nt::NamedTuple) = ConditionalModel(m) | nt

Base.:|(cm::ConditionalModel, nt::NamedTuple) = ConditionalModel(cm.model, cm.args, merge(cm.obs, nt))
