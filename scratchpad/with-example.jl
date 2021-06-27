using Soss, TupleVectors, MeasureTheory
import SampleChainsDynamicHMC: DynamicHMCChain

m = @model begin
    μ ~ Normal(0,1)
    σ ~ HalfCauchy()
    x ~ Normal(μ,σ)
end;


post = sample(DynamicHMCChain, m() | (;x =3.0)) |> TupleVector

@with post (t_stat=μ/σ,)

import Sobol
ω = SobolHypercube(1)
@with (;ω) post (; x=rand(ω,Normal(μ,σ)))
