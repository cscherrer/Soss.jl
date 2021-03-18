using Soss, Random
Random.seed!(1);

m = @model X begin
    n = size(X,1)
    k = size(X,2)
    w ~ Normal(0,1) |> iid(k)
    Xw = X * w
    y ~ For(n) do j
        Normal(Xw[j], 0.1)
    end
end;

X = randn(5,2)
y = rand(m(X=X)).y

post = dynamicHMC(m(X=X), (y=y,));
particles(post)

pred = predict(m(X=X), post);

y_rep = particles(pred).y

y_rep .< y
