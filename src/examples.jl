

lda = @model (α, η, K, V, N) begin
    M = length(N)

    β ~ For(1:K) do _
            Dirichlet(repeat([η],V))
        end

    θ ~ For(1:M) do _
            Dirichlet(repeat([α],K))
        end

    z ~ For(1:M) do m
            For(1:N[m]) do _
                Categorical(θ[m])
            end
        end

    w ~ For(1:M) do m
            For(1:N[m]) do n
                Categorical(β[z[m][n]])
            end
        end
end


normalModel = @model N begin
    μ ~ Normal(0,5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    x ~ For(1:N) do n 
        Normal(μ,σ)
    end
end



mix = @model N begin
    p ~ Uniform()
    μ1 ~ Normal(0,1)
    μ2 ~ Normal(0,1)
    σ1 ~ Truncated(Cauchy(0,3), 0, Inf)
    σ2 ~ Truncated(Cauchy(0,3), 0, Inf)
    x ~ For(1:N) do n
        MixtureModel([Normal(μ1, σ1), Normal(μ2, σ2)], [p, 1-p])
    end
end



linReg1D = @model (x) begin
    # Priors chosen following Gelman(2008)
    α ~ Cauchy(0,10)
    β ~ Cauchy(0,2.5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    

    ŷ = α .+ β .* x
    N = length(x)
    y ~ For(1:N) do n 
        Normal(ŷ[n], σ)
    end
end

