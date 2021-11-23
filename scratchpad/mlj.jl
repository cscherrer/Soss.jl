using Revise
using Soss 

m = @model x begin
    α ~ Cauchy()
    β ~ Normal()
    σ ~ HalfNormal()
    y ~ For(x) do xj
        Normal(α + β * xj, σ)
    end
end;

truth = rand(m(x=randn(10)));
using Plots
xx = range(extrema(truth.x)...,length=100)
plot(xx, truth.α .+ truth.β .* xx, legend=false)
scatter!(truth.x,truth.y)

post = dynamicHMC(m(X=truth.X), (y=truth.y,)); 

particles(post)

pred = predictive(m,:β)

function fit(m::DAGModel, verbosity::Integer, X, y)
    fitresult = dynamicHMC(m(X=X), (y=y,))
    cache = nothing
    report = nothing
    (fitresult, cache, report)
end

struct MLJpredictor <: Distributions.Sampleable{Univariate, Continuous}
    pred :: Soss.Model
    Xrow :: Matrix
    βs   :: Vector{NamedTuple}
end

function Base.rand(p::MLJpredictor)
    args = merge(rand(p.βs), (X=p.Xrow,))
    rand(p.pred(args)).y
end

function predict(m, fitresult, Xnew)
    pred = predictive(m, setdiff(variables(m),[:X,:y])...)
    map(eachrow(Xnew)) do x
        X = reshape(x, 1, :)
        MLJpredictor(pred, X, fitresult)
    end
end

fitresult = fit(m, 0, truth.X, truth.y)[1];
p = predict(m,fitresult, rand(4,3));

map(rand, p)




# mutable struct MLJmodel <: MLJ.Probabilistic
#     sampler #function that can do MCMC
#     m :: Soss.Model
# end


# MLJBase.fit(model::SomeSupervisedModel, verbosity::Integer, X, y) -> fitresult, cache, report
# MLJBase.predict(model::SomeSupervisedModel, fitresult, Xnew) -> yhat








    

# function fit(mljModel, verbosity, X, y)
#     # This line is wrong, we'll need to grab the right NamedTuple keys
#     (samples, report) = mljModel.sampler(mljModel.m(X=X), (y=y,))
#     cache = ...
#     (samples, cache, report)
# end



# function Base.rand(p::MLJpredictor)
#     β = rand(p.βs)

#     # This line is wrong, we'll need to grab the right NamedTuple keys
#     rand(p.pred(X=p.Xrow, β=β))
# end

# function predict(mljModel,βs,Xnew)
#     pred = predictive(mljModel.m, mljModel.X)
#     [MLJpredictor(pred, Xrow, βs) for Xrow in eachrow(Xnew)]
# end    
