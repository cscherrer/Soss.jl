using Soss
using MeasureTheory

minit = @model begin
    s ~ Poisson(300_000_000)
    i ~ Poisson(1)
    r ~ Dirac(0)
    d ~ Dirac(0)
end

mstep = @model pars,state begin
    # Parameters
    sp = pars.sp        # Daily transmission rate
    ip = pars.ip
    
    # Starting counts
    s0 = state.s      # Susceptible
    i0 = state.i      # Infected 
    r0 = state.r      # Recovered
    d0 = state.d      # Deceased
    
    # Transitions between states
    s_si  ~ Multinomial(s0, sp)
    i_ird ~ Multinomial(i0, ip)

    Δs = -s_si[2]
    Δi = s_si[2] + i_ird[1]
    Δr = i_ird[2]
    Δd = i_ird[3]

    # Updated counts
    return ( s = s0 + Δs
           , i = i0 + Δi
           , r = r0 + Δr
           , d = d0 + Δd
           )
end;



m = @model begin
    sp ~ Dirichlet(ones(2))
    ip ~ Dirichlet(ones(3))
    pars = (; sp, ip)
    x ~ Chain(minit()) do state mstep(pars, state) end
end


using CSV, DataFrames
covid = CSV.read("/home/chad/git/covid-19/data/countries-aggregated.csv", DataFrame);

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
df[2:end, :si] = .-diff(df.s);
df[!, :ir] .= 0;
df[2:end, :ir] = diff(df.r);
df[!, :id] .= 0;
df[2:end, :id] = diff(df.d);




# just the last 30 days
# df = df[(end-29):end,:];

df = df[1:100,:]
    
using NamedTupleTools
import NamedTupleTools
NamedTupleTools.namedtuple(dfrow::DataFrameRow) = namedtuple(pairs(dfrow).iter.is...)

nts = namedtuple(names(df)).(eachrow(df));


post = sample(DynamicHMCChain, m() | (x=nts,))


α = Particles(post.α[:])
β = Particles(post.β[:])
γ = Particles(post.γ[:])



# R₀
α / (β + γ)

# Case fatality rate
γ / (β + γ)

# Implied infection duration
1/(β + γ)

# julia> α / (β + γ)
# Particles{Float64, 4000}
#  3.42224 ± 0.00201

# julia> γ / (β + γ)
# Particles{Float64, 4000}
#  0.0648367 ± 0.000116

# julia> 1/(β + γ)
# Particles{Float64, 4000}
#  208.969 ± 0.104
