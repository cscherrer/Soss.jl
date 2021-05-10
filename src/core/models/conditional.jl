struct ConditionalModel{A,B,M,Argvals,Obs} <: AbstractModel{A,B,M,Argvals,Obs}
    model :: AbstractModel{A,B,M, Nothing, Nothing}
    argvals :: Argvals
    obs :: Obs
end

function Base.show(io::IO, cm::ConditionalModel)
    println(io, "ConditionalModel given")
    println(io, "    arguments    ", keys(argvals(cm)))
    println(io, "    observations ", keys(observations(cm)))
    println(io, Model(cm))
end

export argvals
argvals(c::ConditionalModel) = c.argvals

export observations
observations(c::ConditionalModel) = c.obs

export observed
function observed(cm::ConditionalModel{A,B,M,Argvals,Obs}) where {A,B,M,Argvals,Obs}
    keys(schema(Obs))
end

Model(c::ConditionalModel) = c.model

ConditionalModel(m::AbstractModel) = ConditionalModel(m,NamedTuple(), NamedTuple())

(m::AbstractModel)(nt::NamedTuple) = ConditionalModel(m)(nt)

(cm::ConditionalModel)(nt::NamedTuple) = ConditionalModel(cm.model, merge(cm.argvals, nt), cm.obs)

(m::AbstractModel)(;argvals...)= m((;argvals...))

(m::AbstractModel)(args...) = m(NamedTuple{Tuple(m.args)}(args...))

import Base

Base.:|(m::AbstractModel, nt::NamedTuple) = ConditionalModel(m) | nt

Base.:|(cm::ConditionalModel, nt::NamedTuple) = ConditionalModel(cm.model, cm.argvals, merge(cm.obs, nt))
