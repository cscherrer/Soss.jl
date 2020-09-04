using SimplTraits
@traitdef IsExpFam{D}
@traitimpl IsExpFam{D} <- isExpFam(D)

isExpFam(D) = false

@traitimpl IsExpFam{Normal{T} where T} = true

@traitfn f(d::D) where {D; IsExpFam{D}} 
