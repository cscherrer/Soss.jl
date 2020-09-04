m = @model x0 begin
    μ ~ HalfNormal(1)
    σ ~ HalfCauchy(1)
    x ~ Normal(x0 + μ, σ)
end

m_fwd = m(:μ,:σ)
m_inv = m(:x)

r = makeRand(m_fwd)

grt = (μ = 0.1, σ = 1.2735923758662662, x0=0.0)

function realize(n; pars...)
    pars = Dict(pars)
    xs = zeros(n)
    for j in 1:n
        newx = r(;pars...).x
        xs[j] = newx
        pars = merge(pars, Dict(:x0=>newx))

    end
    xs
end

obs = realize(1000;grt...)

using Plots
pyplot()
plot(obs)
