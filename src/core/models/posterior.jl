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

export argvals
argvals(c::ModelPosterior) = argvals(c.closure)

export observations
observations(c::ModelPosterior) = c.obs

export observed
function observed(cm::ModelPosterior{M,A,O}) where {M,A,O}
    keys(schema(O))
end

Model(c::ModelPosterior) = c.model

ModelPosterior(m::AbstractModelFunction) = ModelPosterior(m,NamedTuple(), NamedTuple())

(cm::ModelPosterior)(nt::NamedTuple) = ModelPosterior(cm.model, merge(cm.argvals, nt), cm.obs)

Base.:|(cm::ModelPosterior, nt::NamedTuple) = ModelPosterior(cm.model, cm.argvals, merge(cm.obs, nt))
