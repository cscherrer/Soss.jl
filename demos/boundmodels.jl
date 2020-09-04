using Revise
using Soss


m = @model μ begin
    x ~ Normal(μ,1)
end

m(μ=1.0)

rand(m(μ=1.0))

logpdf(m(μ=1.0),(x=0.4,))
# rand(m1)

weightedSample(m(μ=1.0),(x=3,))


m = @model μ begin
    x ~ Normal(μ,1)
end

mμ = m(μ=1)

@btime weightedSample($mμ,(x=3,))
@btime weightedSample($mμ,NamedTuple())
