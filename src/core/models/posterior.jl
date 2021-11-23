struct ModelPosterior{M,A,O}
    closure::ModelClosure{M,A}
    obs::O
end


function Base.show(io::IO, cm::ModelPosterior)
    println(io, "ModelPosterior given")
    println(io, "    arguments    ", keys(argvals(cm)))
    println(io, "    observations ", keys(observations(cm)))
    println(io, Model(cm))
end

type2model(::Type{MP}) where {M, MP<:ModelPosterior{M}} = type2model(M)
type2model(::ModelPosterior{M}) where {M} = type2model(M)


export argvals
argvals(c::ModelPosterior) = argvals(c.closure)

argvalstype(mp::ModelPosterior{M,A}) where {M,A} = A
argvalstype(::Type{MP}) where {M,A,MP<:ModelPosterior{M,A}} = A

obstype(mp::ModelPosterior{M,A,O}) where {M,A,O} = O
obstype(::Type{MP}) where {M,A,O,MP<:ModelPosterior{M,A,O}} = O

export observations
observations(c::ModelPosterior) = c.obs

export observed
function observed(cm::ModelPosterior{M,A,O}) where {M,A,O}
    keys(schema(O))
end

Model(post::ModelPosterior) = Model(post.closure)

ModelPosterior(m::AbstractModelFunction) = ModelPosterior(m,NamedTuple(), NamedTuple())

(cm::ModelPosterior)(nt::NamedTuple) = ModelPosterior(cm.model, merge(cm.argvals, nt), cm.obs)

Base.:|(cm::ModelPosterior, nt::NamedTuple) = ModelPosterior(cm.model, cm.argvals, merge(cm.obs, nt))
