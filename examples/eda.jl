using CSV
using DataFrames
using DataFramesMeta

covid = dropmissing(CSV.read("/home/chad/git/covid-19-data/us-counties.csv"))
# covid = @where(covid, :cases .> 0)
pop = let
    df = CSV.read("/home/chad/git/covid-19-data/co-est2019-alldata.csv")
    DataFrame([
        :fips => 1000 .* df.STATE .+ df.COUNTY 
        :pop  => df.POPESTIMATE2019
        :births_pre => Int.(vec(mapslices(
            median,
            hcat( df.BIRTHS2011
                , df.BIRTHS2012
                , df.BIRTHS2013
                , df.BIRTHS2014
                , df.BIRTHS2015
                , df.BIRTHS2016
                , df.BIRTHS2017
                , df.BIRTHS2018
                , df.BIRTHS2019
                )
            ; dims=2
        )))
        :deaths_pre => Int.(vec(mapslices(
            median,
            hcat( df.DEATHS2011
                , df.DEATHS2012
                , df.DEATHS2013
                , df.DEATHS2014
                , df.DEATHS2015
                , df.DEATHS2016
                , df.DEATHS2017
                , df.DEATHS2018
                , df.DEATHS2019
                )
            ; dims=2
        )))
    ]
    )
end

# covid = join(covid, pop, on=:fips)
using Dates
# covid = @where(covid, :date .> DateTime(2020,3))
using Dates
covid[:day] = dayofyear.(covid[:date])

per(a,b) = a/b

rates = DataFrame(Dict(:fips => 0, :dcase => 0.0, :ddeath => 0.0))
using GLM
for df in groupby(covid, :fips)
    start = 1 # max(size(df,1)-7, 1)
    try
        m = glm(@formula(per(cases, pop) ~ 1 + day), df[start:end,:], Binomial(), LogitLink())
        dcase = m.model.pp.beta0[2]

        m = glm(@formula(per(deaths, pop) ~ 1 + day), df[start:end,:], Binomial(), LogitLink())
        ddeath = m.model.pp.beta0[2]
        push!(rates, Dict(:fips => df[1,:fips],:dcase => dcase, :ddeath => ddeath))


    catch PosDefException
        continue
    end
    
end

covid = join(covid, rates, on=:fips)
covid.dcase .= max.(0,covid.dcase)
covid.ddeath .= max.(0,covid.ddeath)
grouped = groupby(covid, :fips)
latest = vcat([df[[end],:] for df in grouped]...)
latest=latest[sortperm(latest.ddeath),:]

using Plots, StatsPlots

# @df (@where(latest, :deaths .> 2)) scatter(:dcase, :ddeath)

# @df (@where(latest, :cases .> 2)) scatter(:pop, :ddeath, xscale=:log10)



# using Plots
# scatter(latest.cases, latest.pop, xscale=:log10, yscale=:log10)


# using StatsPlots
# @df (@where(latest, :cases .> 2)) scatter(:pop, :rate, xscale=:log10)


# ylims!(plt, 1e-6,1e-2)
# plt

# covid = let
#     path = "/home/chad/git/COVID-19/csse_covid_19_data/csse_covid_19_daily_reports/"
#     files = filter(fname -> endswith(fname, "csv"),readdir(path, join=true))
#     data = CSV.read(files[61])
#     data = data[data[:Country_Region] .== "US",:]
#     for f in files[62:end]
#         newdata = CSV.read(f)
#         newdata = newdata[newdata[!,:Country_Region] .== "US",:]
#         append!(data, newdata) 
#     end
#     select(data, 
#         [ :FIPS
#         , :Admin2
#         , :Province_State
#         , :Country_Region
#         # , :Last_Update
#         # , :Lat
#         # , :Long_
#         , :Confirmed
#         , :Deaths
#         , :Recovered
#         , :Active
#         ]) |> dropmissing
# end


king = @where(covid, :fips .== 53033)
sarasota = @where(covid, :county .== "Sarasota")
dubois = @where(covid, :county .== "Dubois")

using NamedTupleTools
import NamedTupleTools
NamedTupleTools.namedtuple(dfrow::DataFrameRow) = namedtuple(pairs(dfrow).iter.is...)

namedtuples(df::DataFrame) = namedtuple(names(df)).(eachrow(df))
namedtuples(df::SubDataFrame) = namedtuple(names(df)).(eachrow(df))
namedtuples(df::GroupedDataFrame) = [namedtuple(names(df[j])).(eachrow(df[j])) for j in 1:length(df)] 

using Soss

m = @model begin
    μ ~ Normal(0,100)
    σ ~ HalfCauchy()
    r ~ For(ncty) do cty
        Normal(μ,σ)
    end
    d ~ For(ncty) do cty
        Poisson(

cty = @model pop, μα, σα, μβ, σβ, day0, day1 begin
    α ~ Normal(μα, σα)
    β ~ Normal(μβ, σβ)
    cases ~ For(day0:day1) do j
        Binomial(pop,(day[j]- α)/β)
    end
end

m = @model days, pops begin
    μα ~ Normal(0,100)
    logσα ~ Normal(0,100)
    σα = exp(logσα)

    μβ ~ Normal(0,100)
    logσβ ~ Normal(0,100)
    σβ = exp(logσβ)
    
    c ~ For(days) do j
        cty(pop=pops[j], μα=μα,σα=σα,μβ=μβ,σβ=σβ,
end

using Plots
plot(king.deaths)

# covid = CSV.read("/home/chad/git/covid-19/data/countries-aggregated.csv")
# covid = @where(covid, :Confirmed .> 0)

# us = @where(covid, :Country .== "US")

using Plots
diff(us[:Confirmed]) |> plot

using Soss
using Distributions

struct MarkovChain{P,D}
    pars :: P
    dist :: D
end

function Distributions.logpdf(chain::MarkovChain, x::AbstractVector{X}) where {X}
    @inbounds x1 = (pars=chain.pars,state=x[1])
    length(x) == 1 && return logdensity(chain.dist, x1.state)
    chain_next = MarkovChain(chain.pars, chain.dist.model(x1))
    v = @inbounds @view x[2:end]
    result = logdensity(chain.dist, x1.state)
    chain = chain_next
    x = v
    return result + logdensity(chain,x)
end


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
end;


using NamedTupleTools


using Plots




m = @model s0 begin
    α ~ Uniform()
    β ~ Uniform()
    γ ~ Uniform()
    pars = (α=α, β=β, γ=γ)
    x ~ MarkovChain(pars, mstep(pars=pars, state=s0))
end


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


nts = namedtuple(names(df)).(eachrow(df))


logdensity(m(), (α=0.3,β=0.1,γ=0.02,x=nts))

# Turn a row of a DataFrame into a named tuple
NamedTupleTools.namedtuple(dfrow::DataFrameRow) = namedtuple(pairs(dfrow).iter.is...)

s0 = namedtuple(df[1,:])
post = dynamicHMC(m(s0=s0),(x=namedtuple.(eachrow(df)),));
ppost=particles(post)

α = 0.279
β = 0.00233
γ = 0.00424

pars = (α=α,β=β,γ=γ)
function f(pars)

    n=331000000
    i0 = 10
    s = (n=n,s=n-i0,i=i0,r=0,d=0)

    sim = []
    iter = 0
    while s.i>0 && iter < 10000
        s = select(rand(mstep(pars=pars,state=s)),(:n,:s,:i,:r,:d,:si,:ir,:id))
        push!(sim, s)
        iter += 1
    end
    return sim
end
sim =f(pars) |> DataFrame
