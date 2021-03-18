using Soss

N = 10000

m = @model x, λ begin
    σ ~ Exponential(λ)
    β ~ Normal(0,1) 
    y ~ For(1:N) do j
        Normal(x[j] * β, σ)
    end
    return y
end

x = randn(N)
λ = 1.0

trace = simulate(m(x=x, λ=1.0)).trace
y = trace.y

post = m(; x, λ) | (; y)
ℓ = symlogdensity(post)
