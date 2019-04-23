const locationScaleDists = [:Normal, :Cauchy, :Uniform, ]

export uncenter
function uncenter(model)
    body = postwalk(model.body) do x
        if @capture(x, dist_(μ_,σ_)) && dist ∈ locationScaleDists
            @q ($dist() >>= (x -> (Delta($σ*x + $μ))))
        else x
        end
    end
    Model(model.args, flatten(body))
end
