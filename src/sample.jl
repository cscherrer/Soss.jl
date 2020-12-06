import StatsBase

function StatsBase.sample(rng::AbstractRNG, cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals}
    m = Model(cm)
    cm0 = setReturn(m, nothing)(argvals(cm))
    info = StructArray(rand(rng, cm0, N))
    vals = [predict(cm, pars) for pars in info]
    return StructArray{Noted}((vals, info))
end

function StatsBase.sample(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals} 
    return sample(GLOBAL_RNG, cm, N)
end


function StatsBase.sample(rng::AbstractRNG, cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}) where {A,B,M,Argvals}
    m = Model(cm)
    cm0 = setReturn(m, nothing)(argvals(cm))
    info = rand(rng, cm0)
    val = predict(cm, info)
    return Noted(val, info)
end

function StatsBase.sample(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}) where {A,B,M,Argvals}
    return sample(GLOBAL_RNG, cm)
end
