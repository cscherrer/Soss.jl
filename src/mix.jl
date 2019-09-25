
struct Mix
    dists :: For
    logweights :: Vector
end

export Mix
Mix(w::Vector) = dists -> Mix(dists, log.(w))

function Base.rand(mix::Mix)
    # This is the "Gumbel max trick"  for categorical sampling
    (j_max,lw_max) = (0,-Inf)

    for (j,lw) in enumerate(mix.logweights)
        lw_gumbel = lw + rand(Gumbel())
        if lw_gumbel > lw_max
            (j_max,lw_max) = (j, lw_gumbel)
        end
    end

    mix.dists.f(mix.dists.θs[j_max]) |> rand
end

function Base.rand(mix::Mix, N::Int)
    x1 = rand(mix)
    x = Vector{typeof(x1)}(undef, N)
    @inbounds x[1] = x1
    @inbounds for n in 2:N
        x[n] = rand(mix)
    end
    x
end

xform(mix::Mix) = xform(mix.dists.θs[1])

function Distributions.logpdf(mix::Mix, x)
    ℓ = 0.0
    for (j, θ) in enumerate(mix.dists.θs)
        ℓ = logaddexp(ℓ, mix.logweights[j] + logpdf(mix.dists.f(θ), x))
    end
    ℓ
end

function Mix(x :: Vector, w :: Vector)
    f = For(identity, x) 
    Mix(f, log.(w))
end