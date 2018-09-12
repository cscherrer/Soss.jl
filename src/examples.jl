export rats, pumps, normalModel, seeds

using Iterators

coin = @model flips begin
    pHeads ~ Beta(1,1)
    flips ⩪ Bernoulli(pHeads) |> iid(20) 
end

lda = @model (α, η, K, V, N) begin
    M = length(N)

    β ~ Dirichlet(repeat([η],V)) |> iid(K)
 
    θ ~ Dirichlet(repeat([α],K)) |> iid(M)

    z ~ For(1:M) do m
            Categorical(θ[m]) |> iid(N[m]) 
        end

    w ⩪ For(1:M) do m
            For(1:N[m]) do n
                Categorical(β[z[m][n]])
            end
        end
end

normalModel = @model x begin
    μ ~ Normal(0,5)
    σ ~ HalfCauchy(3)
    N = length(x)
    x ⩪ Normal(μ,σ) |> iid(N)
end

export mix
mix = @model (K,α) begin
    p ~ Dirichlet(repeat([α],K))
    μ ~ Cauchy(0,5) |> iid(K)
    σ ~ HalfCauchy(3) |> iid(K)
    components = Normal.(μ,σ)
    N ~ Poisson(100)
    x ~ MixtureModel(components, p) |> iid(N)
end


linReg1D = @model (x,y) begin
    # Priors chosen following Gelman(2008)
    α ~ Cauchy(0,10)
    β ~ Cauchy(0,2.5)
    σ ~ HalfCauchy(3)
    
    ŷ = α .+ β .* x
    N = length(x) 
    y ⩪ For(1:N) do n
        Normal(ŷ[n], σ)
    end
end


# From OpenBUGS and section 6 of Gelfand et al. 
rats = @model x begin
    μdist = Normal(0,1000)
    μα ~ μdist
    μβ ~ μdist

    σ2dist = InverseGamma(0.001,0.001)
    σ2α ~ σ2dist
    σ2β ~ σ2dist
    σ2c ~ σ2dist

    α ~ Normal(μα, sqrt(σ2α)) |> iid(30)
    β ~ Normal(μβ, sqrt(σ2β)) |> iid(30)

    x̄ = mean(x)
    y ⩪ For([(i,j) for i in 1:30, j in 1:5]) do (i,j)
            Normal(α[i] + β[i]*(x[j]-x̄), sqrt(σ2c))
        end
end

pumps = @model t begin
    n = length(t)
    α ~ Gamma(1,1)
    β ~ Gamma(0.1,1)
    θ ~ For(1:n) do i
            Gamma(α, 1/β)
        end
    y ⩪ For(1:n) do i 
            Poisson(θ[i] * t[i])
        end
end

# dogs = @model
#     lo = typemin(Float64) |> nextfloat
#     negReals = Uniform(lo,-1e-5)
#     α ~ negReals
#     β ~ negReals
#     y ~ For()
#     Bernoulli 
#     α
# end

seeds = @model (n,x) begin
    σ2 ~ InverseGamma(0.001,0.001)
    σ = sqrt(σ2)
    αDist = Normal(0,1000)
    α0 ~ αDist
    α1 ~ αDist
    α2 ~ αDist
    α12 ~ αDist
    b ~ Normal(0,σ) |> iid(21)
    y = α0 .+ α1 .* x[1,:] .+ α2 .* x[2,:] .+ α12 .* x[1,:] .* x[2,:] .+ b
    r ⩪ For(1:21) do i 
            LogisticBinomial(n[i],y[i])
        end
end

# stacks = @model
#     σ2 ~ InverseGamma(0.001,0.001)
#     βDist = Normal(0,1000)
#     β0 ~ βDist
#     β1 ~ βDist
#     β2 ~ βDist
#     β3 ~ βDist 
#     μ = β0 + β1*z[1,:] + β2*z[2,:] + β3*z[3,:] 
#     y ~ For(1:21) do i
#             Laplace(μ[i],σ2)
#         end   
# end