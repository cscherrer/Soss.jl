using Revise
using Soss
using Random

# Build the model

m = @model Prior,x,σ begin
    β ~ Prior
    yhat = β .* x
    y ~ For(eachindex(x)) do j
        Normal(yhat[j], σ)
    end
end

# Sample from generative model

Random.seed!(42);


x = randn(3);
Prior = Normal()
args = (Prior=Prior, x=x, σ=2.0);
truth = rand(m(args));

pairs(truth)

# Joint Distributions

pairs(args)

m(args)

# Evaluate log density

pairs(truth)

logpdf(m(args), truth)

# Sample from posterior

pairs(args)

post = dynamicHMC(m(args), (y=truth.y,));
particles(post)

# Determine predictive distribution

pred = predictive(m, :β)

# Sample from posterior predictive distribution

particles(post)

argspost = merge(args, particles(post));
pairs(argspost)

postpred = pred(argspost) |> rand;
pairs(postpred)

q = @model λ begin
β ~ Normal(λ,1)
end

# imp(m(args),q(λ=1.0),truth)
# importanceSample(m(args),q(λ=1.0),truth)

# particles(m(args))