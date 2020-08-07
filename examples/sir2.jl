
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
    n = s0 + i0 + r0  # Population
    
    # Transitions between states
    si ~ Binomial(s0, α * i0 / n)
    ir ~ Binomial(i0, β)
    id ~ Binomial(i0 - ir, γ)

    # Updated counts
    next = ( state = 
        ( s = s0 - si 
        , i = i0 + si - ir - id
        , r = r0 + ir
        , d = d0 + id
        ),)
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


# Some simple data cleaning - each column should be non-decreasing
# Fix decreasing values with geometric mean
for j in [:Confirmed, :Recovered, :Deaths]
    for i in 2:(size(us,1) - 1)
        if us[i, j] < us[i-1, j]
            us[i,j] = round(Int, sqrt(us[i-1,j] * us[i+1,j]))
        end
    end
end

using DataFrames
df = DataFrame(
    :i => us.Confirmed .- us.Recovered .- us.Deaths
    , :r => us.Recovered 
    , :d => us.Deaths
)
n = 331000000

df[!, :s] .= n .- df.i .- df.r .- df.d
df[!, :si] .= 0
df[:si][2:end] = .-diff(df.s)
df[!, :ir] .= 0
df[:ir][2:end] = diff(df.r)
df[!, :id] .= 0
df[:id][2:end] = diff(df.d)

using NamedTupleTools
import NamedTupleTools
NamedTupleTools.namedtuple(dfrow::DataFrameRow) = namedtuple(pairs(dfrow).iter.is...)

nts = namedtuple(names(df)).(eachrow(df))



s0 = namedtuple(df[1,:])
post = dynamicHMC(m(s0=s0),(x=namedtuple.(eachrow(df)),));
ppost=particles(post)

pred = [predict(m(s0=namedtuple(df[1,:])), postj) for postj in post]


function simulate(pars::NamedTuple, s0, num_steps)
    pred = predict(m(s0=s0), pars)
    return collect(Iterators.take(pred.x, num_steps))
end


function simulate(pars::Vector, s0, num_steps)
    return simulate(rand(pars), s0, num_steps)
end


using Plots

plt = let
    sim = simulate(post, s0, 1000)
    plot(getproperty.(sim, :i))
end

# using Plots

# plt = let
#     p = Iterators.take(pred[1].x, 1000) |> collect
#     plot(0.1 .+ getproperty.(p, :i), legend=:false, c=:black, alpha=0.02)
# end

# for n in 1:1000
#     indx = rand(1:1000)
#     p = Iterators.take(pred[indx].x, 1000) |> collect
#     plot!(plt, 0.1 .+ getproperty.(p, :i), legend=:false, c=:black, alpha=0.02)
# end

# plt

# plot(getproperty.(Iterators.take(pred[rand(1:1000)].x, 1000) |> collect, :i))
