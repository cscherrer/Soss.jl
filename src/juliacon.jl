using Soss
using LaTeXStrings


m = @model x begin
    μ ~ Normal(0,5)
    σ ~ HalfCauchy(3)
    N = length(x)
    x ~ Normal(μ, σ) |> iid(N)
end

f = makeLogdensity(m)
μμ = range(-10,10,length=1000)

normalize(seq) = seq ./ sum(seq)
plot(μμ, [exp(f((μ=μ,σ=1,x=[]))) for μ in μμ] |> normalize, label=L"P(\mu)",legendfontsize=16,dpi=300)
plot!(μμ, [exp(f((μ=μ,σ=1,x=[-5]))) for μ in μμ] |> normalize, label=L"P(\mu|x=-5)")
savefig("/home/chad/prior-posterior.png")

mPrior = prior(m)

rand(mPrior)

particles(mPrior)

nuts(m; x=randn(10))

m2 = @model x,errDist begin
    μ ~ Normal(0,5)
    σ ~ HalfCauchy()
    N = length(x)
    d = LocationScale(μ,σ,errDist)
    x ~ d |> iid(N)
end

nuts(m; x=randn(10), errDist = Normal()).samples[1:3] |> DataFrame

nuts(m; x = randn(10), errDist = TDist(3)).samples[1:3] |> DataFrame

# tdist = @model ν begin
#     w ~ InverseGamma(ν / 2, ν / 2)
#     x ~ Normal(0, w ^ 2)
#     return x
# end

nuts(m; x = randn(10), errDist = tdist, ν=3).samples[1:3] |> DataFrame



p = @model begin
    α ~ Normal(1,1)
    β ~ Normal(α^2,1)
end


q = @model μα,σα,μβ,σβ begin
    α ~ Normal(μα,σα)
    β ~ Normal(μβ,σβ)
end 

f = sourceParticleImportance(p,q) |> eval

f = sourceParticleImportance(p,q) |> eval
(ℓ,θ) = f(1000,(μα=1, σα=1, μβ=2, σβ=2.6))
@unpack (α,β) = θ
scatter(α.particles, β.particles
    , alpha=exp(ℓ - maximum(ℓ)).particles
    , legend=false
    , xlim=(-2,3)
    , ylim=(-3,10)
    , xlabel=L"\alpha"
    , ylabel=L"\beta")
savefig("/home/chad/banana.svg")

q = @model μm,μs,σm,σs begin
    μ ~ Normal(μm,μs)
    σ ~ LogNormal(σm,σs)
end


using LaTeXStrings
f = sourceParticleImportance(p,q) |> eval
(ℓ,θ) = f(1000,(μα=1, σα=1, μβ=2, σβ=2.6))
@unpack (α,β) = θ
scatter(α.particles, β.particles
    , alpha=exp(ℓ - maximum(ℓ)).particles
    , legend=false
    , xlim=(-2,3)
    , ylim=(-3,10)
    , xlabel=L"\alpha"
    , ylabel=L"\beta")
savefig("/home/chad/banana.svg")




#############################
# Example problem
