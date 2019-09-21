
struct Mix
    dists :: For
    logweights :: Vector{Float64}
end

export Mix
Mix(w::Vector) = dists -> Mix(dists, log.(w))

function Base.rand(mix::Mix)
    # This is the "Gumbel max trick"  for categorical sampling
    j = argmax(mix.logweights .+ rand(Gumbel()))
    mix.dists.f(mix.dists.θs[j]) |> rand
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


function Distributions.logpdf(mix::Mix, x)
    ℓ = 0.0
    for (j, θ) in enumerate(mix.dists.θs)
        ℓ = logaddexp(ℓ, mix.logweights[j] + logpdf(mix.dists.f(θ), x))
    end
    ℓ
end

function Mix(x :: Vector, w :: Vector{Float64})
    f = For(identity, x) 
    Mix(f, log.(w))
end