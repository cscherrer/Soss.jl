

normalModel = quote
    μ ~ Normal(0,5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    for x in DATA
        x <~ Normal(μ,σ)
    end
end


mix = quote
    p ~ Uniform()
    μDist = Normal(0,1)
    σDist = Truncated(Cauchy(0,3), 0, Inf)
    componentFamily = Normal
    μ1 ~ μDist
    μ2 ~ μDist
    σ1 ~ σDist
    σ2 ~ σDist
    comp1 = componentFamily(μ1, σ1)
    comp2 = componentFamily(μ2, σ2)
    for x in DATA
        x <~ MixtureModel([comp1, comp2], [p, 1-p])
    end
end

linReg1D = quote
    # Priors chosen following Gelman(2008)
    α ~ Cauchy(0,10)
    β ~ Cauchy(0,2.5)
    σ ~ Truncated(Cauchy(0,3), 0, Inf)
    
    (x,y) = DATA
    ŷ = α + β .* x
    for j in indices(x)
        y[j] <~ Normal(ŷ[j], σ)
    end
end