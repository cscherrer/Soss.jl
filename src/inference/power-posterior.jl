function power_posterior(cm::ConditionalModel)
    m = cm.model

    pr = prior(m, observed(cm)...)
    lik = likelihood(m, observed(cm)...)

    avs = argvals(cm)
    obs = observations(cm)
    function f(t, x) 
        logdensity(pr(avs), x) + t * logdensity(lik(merge(avs, x)) | obs)
    end

    return f
end


# EXAMPLE
# m = @model begin
#     x ~ Normal()
#     y ~ Normal(x,1) |> iid(3)
#     return y
# end;

# prior(m, :y)

# likelihood(m, :y)

# y = rand(m())

# f = power_posterior(m() | (;y))

# f(1.0, (x=0.2,))
# f(0.0, (x=0.2,))
