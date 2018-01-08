

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



linReg1D = @model (N,x) begin
    # Priors chosen following Gelman(2008)
    α ~ Cauchy(0,10)
    β ~ Cauchy(0,2.5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    
    ŷ = α + β .* x
    y ~ For(1:N) do n 
        Normal(ŷ[n], σ)
    end
end

