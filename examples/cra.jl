using Soss

m = @model Prior,x,σ begin
    β ~ Prior
    yhat = β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], σ)
    end
end


x = randn(3);
Prior = Normal()
truth = rand(m(Prior=Prior, x=x, σ=2.0));

pairs(truth)


post = dynamicHMC(m(Prior=Prior, x=x, σ=2.0), (y=truth.y,));
particles(post)

pred = predictive(m, :β)

predictive(m,:yhat)