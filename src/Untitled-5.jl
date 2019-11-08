

function gumbelmachine(n)


function draw_categorical(logweights, draw_gumbels)
    bestℓ₀ = -Inf
    bestℓ = -Inf

    gumbels = draw_gumbels()
    for (j, ℓ₀) in enumerate(logweights)
        @inbounds ℓ = ℓ₀ + gumbels[j]
        if ℓ > bestℓ
            bestj = j
            bestℓ₀ = ℓ₀
            bestℓ = ℓ
        end
    end
    (bestj, bestℓ₀)
end

