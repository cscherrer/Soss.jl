using Soss, Stheno
using DataFrames, CSV

births1 = CSV.read("/home/chad/git/fivethirtyeight_data/births/US_births_1994-2003_CDC_NCHS.csv")
births2 = CSV.read("/home/chad/git/fivethirtyeight_data/births/US_births_2000-2014_SSA.csv")

using Plots

gpc = GPC()
k7 = kernel(EQ(); l=7, s=0.9)

m = @model x begin
    α ~ Normal(9,5)
    β ~ Normal()    
    ϕ ~ Exponential() # overdispersion
    f7 = GP(x -> α + β*x, k7, gpc)
    f = f7
    μ ~ f(x, ϕ)
    y .~ Poisson.(exp.(μ))
end

x = [1:50;];

rand(m(x=x))

# logpdf(m(x=x), (;α=9.0, β=0.1, y=births2.births))

post = dynamicHMC(m(x=x), (;y=births2.births[1:50]))


k = kernel(EQ(); l=7, s=0.9);
f = GP(k, gpc)([1:7;])

f([0.1],4)
