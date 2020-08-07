using Soss
using NNlib:softmax

m = @model X,numGroups begin
    numFeatures = size(X,2)
    β ~ Normal() |> iid(numFeatures, numGroups)
    p = softmax.(eachrow(X*β))
    y ~ For(eachindex(p)) do j
            Categorical(p[j])
        end
end

X = randn(10,4);
k = 3; 

truth = rand(m(X=X, numGroups=k));

pairs(truth)

post = dynamicHMC(m(X=X,numGroups=k), (y=truth.y,));

post[1:3]

pred = predictive(m, :β)



rand(pred((X=X, rand(post)...))).y

logsumexp([logpdf(pred((X=X, p...)), (y=truth.y,)) for p in post]) - log(length(post))