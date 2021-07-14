using Soss

mstep = @model pars,state begin
    # Parameters
    α = pars.α        # Daily transmission rate
    β = pars.β        # Daily recovery rate
    γ = pars.γ        # Daily case fatality rate
    
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
    return ( s = s0 - si 
           , i = i0 + si - ir - id
           , r = r0 + ir
           , d = d0 + id
           )
end;



m = @model s0 begin
    α ~ Uniform()
    β ~ Uniform()
    γ ~ Uniform()
    pars = (α=α, β=β, γ=γ)
    x ~ Chain(s0) do s
            mstep(pars, s)
        end
end


using CSV
covid = CSV.read("/home/chad/git/covid-19/data/countries-aggregated.csv");

using DataFramesMeta


us = @where(covid, :Country .== "US");


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
    :i => us.Confirmed
    , :r => us.Recovered 
    , :d => us.Deaths
    )
n = 331000000

df[!, :s] .= n .- df.i .- df.r .- df.d;
df[!, :si] .= 0;
df[:si][2:end] = .-diff(df.s);
df[!, :ir] .= 0;
df[:ir][2:end] = diff(df.r);
df[!, :id] .= 0;
df[:id][2:end] = diff(df.d);

# just the last 30 days
df = df[(end-29):end,:];
    
using NamedTupleTools
import NamedTupleTools
NamedTupleTools.namedtuple(dfrow::DataFrameRow) = namedtuple(pairs(dfrow).iter.is...)

nts = namedtuple(names(df)).(eachrow(df));



s0 = namedtuple(df[1,:]);
post = dynamicHMC(m(s0=s0),(x=namedtuple.(eachrow(df)),));
ppost=particles(post)




# R₀
ppost.α / (ppost.β + ppost.γ)

# Case fatality rate
ppost.γ / (ppost.β + ppost.γ)

# Implied infection duration
1/(ppost.β + ppost.γ)