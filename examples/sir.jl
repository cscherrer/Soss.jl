
using Soss
using Distributions




mstep = @model pars,state begin
    # Parameters
    α = pars.α        # Transmission rate
    β = pars.β        # Recovery rate
    γ = pars.γ        # Case fatality rate
    
    # Starting counts
    s0 = state.s      # Susceptible
    i0 = state.i      # Infected 
    r0 = state.r      # Recovered
    d0 = state.d      # Deceased
    n = state.n       # Population size

    # Transitions between states
    si ~ Binomial(s0, α * i0 / n)
    ir ~ Binomial(i0, β)
    id ~ Binomial(i0, γ)

    # Updated counts
    s = s0 - si 
    i = i0 + si - ir - id
    r = r0 + ir
    d = d0 + id
    next = (pars=pars, state=(s=s,i=i,r=r,d=d))
end;


using NamedTupleTools


m = @model s0 begin
    α ~ Uniform()
    β ~ Uniform()
    γ ~ Uniform()
    pars = (α=α, β=β, γ=γ)
    x ~ MarkovChain(pars, mstep(pars=pars, state=s0))
end


using CSV
covid = CSV.read("/home/chad/git/covid-19/data/countries-aggregated.csv")

using DataFramesMeta
us = @where(covid, :Country .== "US")

using DataFrames
df = DataFrame(
    :i => us.Confirmed
    , :r => us.Recovered 
    , :d => us.Deaths
)
df[:n] = 331000000
df[:s] = df.n .- df.i .- df.r .- df.d
df[:si] = 0
df[:si][2:end] = .-diff(df.s)
df[:ir] = 0
df[:ir][2:end] = diff(df.r)
df[:id] = 0
df[:id][2:end] = diff(df.d)

using NamedTupleTools
import NamedTupleTools
NamedTupleTools.namedtuple(dfrow::DataFrameRow) = namedtuple(pairs(dfrow).iter.is...)

nts = namedtuple(names(df)).(eachrow(df))



s0 = namedtuple(df[1,:])
post = dynamicHMC(m(s0=s0),(x=namedtuple.(eachrow(df)),));
ppost=particles(post)



α = mean(ppost.α.particles)
β = mean(ppost.β.particles)
γ = mean(ppost.γ.particles)

pars = (α=α,β=β,γ=γ)


function f(pars)

    n=331000000
    i0 = 10
    s = (n=n,s=n-i0,i=i0,r=0,d=0)

    sim = []
    iter = 0
    while s.i>0 && iter < 10000
        s = NamedTupleTools.select(rand(mstep(pars=pars,state=s)),(:n,:s,:i,:r,:d,:si,:ir,:id))
        push!(sim, s)
        iter += 1
    end
    return sim
end
sim =f(pars) |> DataFrame
