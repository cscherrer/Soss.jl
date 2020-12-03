import StatsBase

function StatsBase.sample(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals}
    m = Model(cm)
    cm0 = setReturn(m, nothing)(argvals(cm))
    info = StructArray(rand(cm0,N))
    vals = [predict(m(a=0), pars) for pars in info]
    return StructArray{Noted}((vals, info))
end
