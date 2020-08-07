````julia
using Soss
using RDatasets
df = RDatasets.dataset("ISLR", "Default");
df.Default = df.Default .== "Yes"
df.Student = df.Student .== "Yes"
df
````


````
10000×4 DataFrame
│ Row   │ Default │ Student │ Balance │ Income  │
│       │ Bool    │ Bool    │ Float64 │ Float64 │
├───────┼─────────┼─────────┼─────────┼─────────┤
│ 1     │ 0       │ 0       │ 729.526 │ 44361.6 │
│ 2     │ 0       │ 1       │ 817.18  │ 12106.1 │
│ 3     │ 0       │ 0       │ 1073.55 │ 31767.1 │
│ 4     │ 0       │ 0       │ 529.251 │ 35704.5 │
│ 5     │ 0       │ 0       │ 785.656 │ 38463.5 │
│ 6     │ 0       │ 1       │ 919.589 │ 7491.56 │
│ 7     │ 0       │ 0       │ 825.513 │ 24905.2 │
⋮
│ 9993  │ 0       │ 0       │ 1111.65 │ 45490.7 │
│ 9994  │ 0       │ 0       │ 938.836 │ 56633.4 │
│ 9995  │ 0       │ 1       │ 172.413 │ 14955.9 │
│ 9996  │ 0       │ 0       │ 711.555 │ 52992.4 │
│ 9997  │ 0       │ 0       │ 757.963 │ 19660.7 │
│ 9998  │ 0       │ 0       │ 845.412 │ 58636.2 │
│ 9999  │ 0       │ 0       │ 1569.01 │ 36669.1 │
│ 10000 │ 0       │ 1       │ 200.922 │ 16863.0 │
````





http://www.stat.columbia.edu/~gelman/research/published/priors11.pdf

````julia
function center(x)
    μ = mean(x)
    σ = std(x; mean=μ)
    return (x .- μ) ./ σ
end

df.inc = center(log.(df.Income))
df.bal = center(log.(df.Balance .+ 0.01))
````


````
10000-element Array{Float64,1}:
  0.22568089982424597
  0.2701337836039711
  0.3770369913124122
  0.09994626354462705
  0.25472080183815626
  0.3163897915622952
  0.27410858986868514
  0.2660310523793513
  0.4077374593658318
 -4.161351809943541
  ⋮
  0.18572876865521695
  0.390699491214603
  0.32450541089605206
 -0.33945136690745087
  0.21590878937978109
  0.240662040090041
  0.2834402477144735
  0.5257077296154306
 -0.2795018444608579
````



````julia
m = @model X,λ begin
    n = size(X,1)
    k = size(X,2)
    α ~ Cauchy(5)
    β ~ TDist(3) |> iid(k)
    yhat = α .+ X * β
    y ~ For(eachrow(X)) do xrow
            BernoulliLogistic(yhat)
        end
end
````


````
@model (X, λ) begin
        α ~ Cauchy(5)
        n = size(X, 1)
        k = size(X, 2)
        β ~ TDist(3) |> iid(k)
        yhat = α .+ X * β
        y ~ For(eachrow(X)) do xrow
                BernoulliLogistic(yhat)
            end
    end
````



````julia
X = Matrix(df[:,[:inc, :bal]])
post = dynamicHMC(m(X=X, λ=1), (y=df.Default,))
````


````
Error: StackOverflowError:
````



````julia
particles(post)
````


````
Error: UndefVarError: post not defined
````


