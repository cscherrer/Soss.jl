using Soss

m = @model σ begin
           μ ~ StudentT(3.0)
           x ~ Normal(μ,σ) ^ 10
           return x
       end;

x = rand(m(σ=3.0));

sourceSymlogdensity(m(σ=3.0) | (;x))

s = symlogdensity(m(σ=3.0))

codegen(m(σ=3.0) | (;x))
