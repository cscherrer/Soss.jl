

using Soss, MeasureTheory

hmm = @model begin
    ε ~ Exponential() #  transition
    σ ~ Exponential() # Observation noise
    x ~ Chain(Normal()) do xj
        Normal(xj, ε)
    end

    y ~ For(x) do xj
        Normal(xj, σ)
    end
end


using Random

_rng = Random.GLOBAL_RNG

# sourceRand(hmm)

σ = rand(_rng, Exponential())
ε = rand(_rng, Exponential())
x = rand(_rng, Chain(Normal()) do xj
            #= REPL[2]:5 =#
            Normal(xj, ε)
        end)
y = rand(_rng, For(x) do xj
            #= REPL[2]:8 =#
            Normal(xj, σ)
        end)





rand(hmm())
