using Pkg
Pkg.add.(
      ["Distributions"
    , "MonteCarloMeasurements"
    , "StatsFuns"
    , "LaTeXStrings"
    , "Plots"])


using Distributions
using MonteCarloMeasurements
using StatsFuns

# Just some setup so inequalities propagate through particles
for rel in [<,>,<=,>=]
    register_primitive(rel)
end


function fromObs(x,y) 
    function logp(α,β)
        ℓ = 0.0
        ℓ += logdensityof(Normal(0,1), α)
        ℓ += logdensityof(Normal(0,2), β)
        yhat = α .+ β .* x
        ℓ += sum(logdensityof.(Normal.(yhat, 1), y) )
        ℓ
    end
end


drawcat(ℓ, k) = [argmax(ℓ + Particles(1000,Gumbel())) for j in 1:k]

asmatrix(ps...) = Matrix([ps...])'

# Kish's effective sample size,
# $n _ { \mathrm { eff } } = \frac { \left( \sum _ { i = 1 } ^ { n } w _ { i } \right) ^ { 2 } } { \sum _ { i = 1 } ^ { n } w _ { i } ^ { 2 } }$

function n_eff(ℓ)
    logw = ℓ.particles
    exp(2 * logsumexp(logw) - logsumexp(2 .* logw))
end


function f(a,b)
    
    # generate data
    x = rand(Normal(),100)
    yhat = a .+ b .* x
    y = rand.(Normal.(yhat, 1))

    # generate p
    logp = fromObs(x,y)

    runInference(x,y,logp)

end

function runInference(x,y,logp)
    N = 1000 

    # initialize q
    q = MvNormal(2,100000.0) # Really this would be fit from a sample from the prior
    α,β = Particles(N,q)
    m = asmatrix(α,β)
    ℓ = sum(logp(α,β)) - Particles(logdensityof(q,m))

    numiters = 60
    elbo = Vector{Float64}(undef, numiters)
    for j in 1:numiters
        α,β = Particles(N,q)
        m = asmatrix(α,β)
        ℓ = logp(α,β) - Particles(logdensityof(q,m))
        elbo[j] = mean(ℓ) 
        ss = suffstats(MvNormal, m,  exp(ℓ - maximum(ℓ)).particles .+ 1/N)
        q = fit_mle(MvNormal, ss)
    end
    (α,β,q,ℓ,elbo)
end




@time (α,β,q,ℓ,elbo) = f(3,4)

using LaTeXStrings
using Plots
plot(1:60, -elbo
    , xlabel="Iteration"
    , ylabel="Negative ELBO"
    , legend=false
    , yscale=:log10)
xticks!([0,20,40,60], [L"0",L"20", L"40",L"60"])
yticks!(10 .^ [3,6,9,12], [L"10^3", L"10^6",L"10^9",L"10^{12}"])
savefig("neg-elbo.svg")

using Soss
import TransformVariables: inverse
import NamedTupleTools: select
using Random
using StructArrays

function structarray(nt::NamedTuple)
    return StructArray(prototype(nt)(getproperty.(values(nt), :particles)))
end

m = @model x begin
    α ~ Normal()
    β ~ Normal()
    p = α .+ β .* x
    y ~ For(eachindex(p)) do j
            BernoulliLogistic(p[j])
        end
end

x = randn(200);

truth = rand(m(x = x));

y = truth.y;



q = MvNormal(2,100.0)






function initialize(jointdist, obs)
    tr = as(jointdist, obs)
    pars = keys(tr.transformations)
    m = jointdist.model

    args = arguments(jointdist)
    prior = Soss.before(m, pars...; inclusive=true)(args)
    pred = predictive(m, pars...)
    samples = structarray(particles(prior))
    q = inverse.(tr, samples) 


    ℓ = [logdensityof(pred(merge(args, s)), obs) for s in samples]
end


inverse.(tr, [rand(prior()) for j in 1:1000])


pred = predictive(m, pars...)


d = length(inverse(tr, rand(prior)))

numSamples = 1000

s = Array{Float64}(undef, d, numSamples)
w = Vector{Float64}(undef, numSamples)

for c in eachcol(s)
    c .= inverse(tr,rand(prior()))
end

function updateSample!(s,q)
    return rand!(q,s)
end

function updateWeights!(w, s, p, tr)
    map!(θ -> logdensityof(p, θ), w, tr.(eachcol(s)))
end

inverse(tr, select(rand(m(x=x)), pars))


Soss.prior(m,:y) |> as

Soss.sourceas(Soss.prior(m,:y))

as()
