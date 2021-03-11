using Soss

p = @model begin
    x ~ Normal()
    y ~ Normal(x,1) |> iid(5)
end;

q = @model λ begin
    μ = λ.x.Ex
    σ = λ.x.Ex²-λ.x.Ex^2
    x ~ Normal(μ, σ)
end;

y = rand(p()).y;


λ = ( _ℓ = -20
    , x = (Ex=0.0, Ex²=1.0)
)

function logweightedmean(ℓ1,x1,ℓ2,x2)
    if ℓ1 < ℓ2
        return logweightedmean(ℓ2,x2,ℓ1,x1)
    elseif isinf(ℓ2)
        return ℓ1
    else
        w = exp(ℓ2 - ℓ1)
        return (x1 + w*x2)/(1+w)
    end
end



importanceSample(p(), q(λ=λ), (y=y,))

function f(λ, n=10) 
    for j in 1:n
        ℓx = importanceSample(p(), q(λ=λ), (y=y,))
        val = ℓx.val
        ℓ = ℓx.ℓ

        x = val.x
        x² = x*x
        x³ = x*x²
        x⁴ = x*x³  
        λ = @set λ.x.Ex = logweightedmean(λ._ℓ+1, λ.x.Ex, ℓ, x)
        λ = @set λ.x.Ex² = logweightedmean(λ._ℓ+1, λ.x.Ex², ℓ, x²)
        λ = @set λ.x.Ex³ = logweightedmean(λ._ℓ+1, λ.x.Ex³, ℓ, x³)
        λ = @set λ.x.Ex⁴ = logweightedmean(λ._ℓ+1, λ.x.Ex⁴, ℓ, x⁴)
     
        λ = @set λ._ℓ = logaddexp(λ._ℓ, ℓ)        
    end
    return λ
end

λ = f(λ,1000)
