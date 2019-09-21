using Revise
using Soss 

m = @model X begin
    β ~ Normal() |> iid(size(X,2))
    y ~ For(eachrow(X)) do x
        Normal(x' * β, 1)
    end
end

truth = rand(m(X=randn(10,3)))



post = dynamicHMC(m(X=truth.X), (y=truth.y,)); 

particles(post)

pred = predictive(m,:β)

posteriorPredictive()

pred(X=truth.X, β=post[1].β)


MLJBase.fit(model::SomeSupervisedModel, verbosity::Integer, X, y) -> fitresult, cache, report
MLJBase.predict(model::SomeSupervisedModel, fitresult, Xnew) -> yhat






mutable struct MLJmodel <: MLJ.Probabilistic
    sampler #function that can do MCMC
    m :: Soss.Model
    X :: Symbol
    y :: Symbol
end

    

function fit(mljModel, verbosity, X, y)
    # This line is wrong, we'll need to grab the right NamedTuple keys
    (samples, report) = mljModel.sampler(mljModel.m(X=X), (y=y,))
    cache = ...
    (samples, cache, report)
end

struct MLJpredictor <: Distributions.Sampleable
    pred :: Soss.Model
    Xrow :: Matrix
    βs   :: Vector{NamedTuple}
end

function Base.rand(p::MLJpredictor)
    β = rand(p.βs)

    # This line is wrong, we'll need to grab the right NamedTuple keys
    rand(p.pred(X=p.Xrow, β=β))
end

function predict(mljModel,βs,Xnew)
    pred = predictive(mljModel.m, mljModel.X)
    [MLJpredictor(pred, Xrow, βs) for Xrow in eachrow(Xnew)]
end    
