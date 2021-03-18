using Soss

p = @model r,s begin
    p_bad ~ Beta(1,3) |> iid(s)
    bad ~ For(s) do j
            Bernoulli(p_bad[j])
        end
    
    fpr ~ Beta(1,3) |> iid(r)
    tpr ~ Beta(3,1) |> iid(r)

    pos_rate = hcat(fpr, tpr)

    y ~ For(r,s) do i,j
        Bernoulli(pos_rate[i, bad[j] + 1])
    end
    return y
end;

markovBlanket(p, :bad)



+





# ASVI
q = @model r,s,λα begin
    λ = λα.λ
    α = λα.α
    p_bad ~ For(s) do j
        a = 1 * λ.p_bad[j,1] + α.p_bad[j,1] * (1 - λ.p_bad[j,1])
        b = 3 * λ.p_bad[j,2] + α.p_bad[j,2] * (1 - λ.p_bad[j,2])
        Beta(a,b)
    end
    bad ~ For(s) do j
            Bernoulli(p_bad[j] * λ.bad[j] + α.bad[j] * (1 - λ.bad[j]))
        end
    tpr ~ For(r) do i 
            a = 3 * λ.tpr[i,1] + α.tpr[i,1] * (1 - λ.tpr[i,1])
            b = 1 * λ.tpr[i,2] + α.tpr[i,2] * (1 - λ.tpr[i,2])
            Beta(a,b)
        end
    fpr ~ For(r) do i
        a = 1 * λ.fpr[i,1] + α.fpr[i,1] * (1 - λ.fpr[i,1])
        b = 3 * λ.fpr[i,2] + α.fpr[i,2] * (1 - λ.fpr[i,2])
        Beta(a,b)
    end
end

tr = as((
    λ=as((
        p_bad = as(Array, as𝕀, 14, 2),
        bad = as(Array, as𝕀, 14),
        tpr = as(Array, as𝕀, 5, 2),
        fpr = as(Array, as𝕀, 5, 2))
        ),
    α = as((
        p_bad = as(Array, asℝ₊, 14, 2),
        bad = as(Array, as𝕀, 14),
        tpr = as(Array, asℝ₊, 5, 2),
        fpr = as(Array, asℝ₊, 5, 2))
        )     
    ))

x = zeros(124)
λα = tr(x)

y = rand(p(r=5, s=14));
posterior = p(r=5, s=14) | (;y)

function elbo(x)
    λ = tr(x)

    qλ = q(r=5,s=14, λα=λα)
    r = rand(qλ)
    logdensity(posterior, r) - logdensity(qλ, r)
end

elbo(x)





using Random
Random.seed!(1);

y_obs = truth.y

obs = (y=y,)

particles(p(r=5,s=14))

entropy(p(r=5,s=14))

lik = predictive(p, :p_bad, :fpr, :tpr)


import TransformVariables
_lik = as((
           p_bad = as(Array, as𝕀, 14),
           fpr = as(Array, as𝕀, 5),
           tpr = as(Array, as𝕀, 5)))

ϕ = Optim.minimizer(result)
t_lik(ϕ)




q = @model r,s,λ begin
    p_bad ~ For(j -> Beta(1+λ.p_bad[j].α, 1+λ.p_bad[j].β), s)

    bad ~ For(j -> Bernoulli(p_bad[j]), s)
    
    fpr ~ For(i -> Beta(1+λ.fpr[i].α, 1+λ.fpr[i].β), r)
    tpr ~ For(i -> Beta(1+λ.tpr[i].α, 1+λ.tpr[i].β), r)
end;


import TransformVariables: as, asℝ₊
trλ = as((λ=as((
    p_bad = as(Array, as((α=asℝ₊, β=asℝ₊)), 14),
    fpr =   as(Array, as((α=asℝ₊, β=asℝ₊)), 5),
    tpr =   as(Array, as((α=asℝ₊, β=asℝ₊)), 5),
)),
))

trλ.dimension



x0 = zeros(48)
λ = trλ(x0)



logdensity(p(r=5, s=14) | (;y), rand(q(r=5,s=14, λ=λ.λ)))




























































function elbo(p, args, obs, q, λ)
    qargs = merge(args, λ)
    mean(logpdf(p(args), merge(particles(q(qargs)), obs))) + entropy(q(args))
end


ϕ0 = zeros(48);
elbo(p,(r=5,s=14), obs, q, trλ(ϕ0))


using Optim
result = optimize(
      ϕ -> -elbo(p,(r=5,s=14),obs, q, trλ(ϕ))
    , ϕ0
    , Optim.Options(
        show_trace=true,
        show_every=100,
        iterations=1000
    )

)


ϕ0 = Optim.minimizer(result)
λ = trλ(ϕ0).λ

particles(q(r=5,s=14, λ=λ)) |> pairs


elbo(p,q,(r=5,s=14),trλ(result))

###################
# ADVI 

using AdvancedVI
# using DistsAD

bad = rand(Bernoulli(0.5) |> iid(14))

tr = xform(p(r=5,s=14), (y=y,));
d = tr.dimension

getq(λ) = MvNormal(λ[1:d], exp.(λ[d .+ (1:d)]))

advi = ADVI(10, 10_000)



function logπ(θ)
    logpdf(p(r=5,s=14),  merge((y=y,), tr(θ)))
end

logπ(randn(24))

λ = vi(logπ, advi, getq, zeros(48)) |> particles |> tr


pairs(λ)
















q = @model r,s,λ begin
    p_bad ~ Uniform() |> iid(s)

    bad ~ For(s) do j
        Bernoulli(λ.bad[j].p)
    end
    
    fpr ~ For(r) do i Beta(λ.fpr[i].α, λ.fpr[i].β, check_args=false) end
    tpr ~ For(r) do i Beta(λ.tpr[i].α, λ.tpr[i].β, check_args=false) end
end;



function logweightedmean(ℓ1,x1,ℓ2,x2)
    if isinf(ℓ1)
        return (x1+x2)/2
    else
        w = exp(ℓ2 - ℓ1)/2
        target = (x1 + w*x2)/(1 + w)
        return 0.7*x1 + 0.3*target
    end
end


λ = ( bad = [(p=0.5,) for j in 1:14] 
    , fpr   = [(α=1.0, β=1.0) for i in 1:5]  
    , tpr   = [(α=1.0, β=1.0) for i in 1:5]
)

importanceSample(p(r=5,s=14), q(r=5,s=14, λ=λ), (y=truth.y,))

function f(λ, N=100, warmup=10) 
    λ0 = deepcopy(λ)

    for iternum in 1:N

        if iternum < warmup
            ℓx = importanceSample(p(r=5,s=14), q(r=5,s=14, λ=λ0), (y=truth.y,))
        else
            ℓx = importanceSample(p(r=5,s=14), q(r=5,s=14, λ=λ), (y=truth.y,))
        end

        x = ℓx.val
        ℓ = ℓx.ℓ

        for j in eachindex(λ.bad)
            bad = x.bad[j]
            p = λ.bad[j].p

            p = logweightedmean(λ._ℓ, p, ℓ, bad)
            λ = @set λ.bad[j].p = p
        end

        for j in eachindex(λ.p_bad)
            p_bad = x.p_bad[j]

            α = λ.p_bad[j].α 
            β = λ.p_bad[j].β
            α_plus_β = α + β
            
            Ex = α / α_plus_β
            Ex² = α * β / (α_plus_β^2 * (α_plus_β + 1)) + Ex^2

            # Update moments
            Ex = logweightedmean(λ._ℓ, Ex, ℓ, p_bad)
            Ex² = logweightedmean(λ._ℓ, Ex², ℓ, p_bad^2)
            
            # Parameter estimates by method of moments
            V = Ex² - Ex^2
            n = Ex * (1 - Ex) / V - 1
            α = max(floatmin(Float32), n * Ex)
            β = max(floatmin(Float32), n * (1 - Ex))

            λ = @set λ.p_bad[j].α = α
            λ = @set λ.p_bad[j].β = β
        end

        for i in eachindex(λ.tpr)
            tpr = x.tpr[i]

            α = λ.tpr[i].α 
            β = λ.tpr[i].β
            α_plus_β = α + β
            
            Ex = α / α_plus_β
            Ex² = α * β / (α_plus_β^2 * (α_plus_β + 1)) + Ex^2

            # Update moments
            Ex = logweightedmean(λ._ℓ, Ex, ℓ, tpr)
            Ex² = logweightedmean(λ._ℓ, Ex², ℓ, tpr^2)
            
            # Parameter estimates by method of moments
            V = Ex² - Ex^2
            n = Ex * (1 - Ex) / V - 1
            α = max(floatmin(Float32), n * Ex)
            β = max(floatmin(Float32), n * (1 - Ex))

            λ = @set λ.tpr[i].α = α
            λ = @set λ.tpr[i].β = β
        end

        for i in eachindex(λ.fpr)
            fpr = x.fpr[i]

            α = λ.fpr[i].α 
            β = λ.fpr[i].β
            α_plus_β = α + β
            
            Ex = α / α_plus_β
            Ex² = α * β / (α_plus_β^2 * (α_plus_β + 1)) + Ex^2

            # Update moments
            Ex = logweightedmean(λ._ℓ, Ex, ℓ, fpr)
            Ex² = logweightedmean(λ._ℓ, Ex², ℓ, fpr^2)
            
            # Parameter estimates by method of moments
            V = Ex² - Ex^2
            n = Ex * (1 - Ex) / V - 1
            α = max(floatmin(Float32), n * Ex)
            β = max(floatmin(Float32), n * (1 - Ex))

            λ = @set λ.fpr[i].α = α
            λ = @set λ.fpr[i].β = β
        end

        λ = @set λ._ℓ = logaddexp(λ._ℓ, ℓ)        
    end
    return λ
end


λ = ( _ℓ = -Inf
    , p_bad = [(α=1.0, β=1.0) for j in 1:14] 
    , bad   = [(p=0.5,) for j in 1:14]
    , fpr   = [(α=1.0, β=1.0) for i in 1:5]  
    , tpr   = [(α=1.0, β=1.0) for i in 1:5]
);


λ = f(λ,20000,100);
λ.bad

sourceParticles()(m, Val{1000})


particles(m(r=5,s=14))
post=dynamicHMC(m2(r=5,s=14), (y=truth.y,))




dynamicHMC(m2(r=5,s=14), (y=truth.y,))

markovBlanket(m, :bad)


m = @model s begin
    p_bad ~ Beta(1,3) |> iid(s)
    bad ~ Normal(p_bad[1],1) |> iid(s)
    end

particles(m(s=3))
