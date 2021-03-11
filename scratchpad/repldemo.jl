using Soss

m = @model x begin
    α ~ StudentT(ν = 3.0)
    β ~ Normal()
    y ~ For(1:1000) do j 
        Normal(μ = α + β * x[j]) 
    end
    return y
end

#####################################

julia> prior(m, :y)
@model begin
        β ~ Normal()
        α ~ StudentT(ν = 3.0)
    end


julia> likelihood(m, :y)
@model (α, β, x) begin
        y ~ For(1:1000) do j
                Normal(μ = α + β * x[j])
            end
    end


############################################


julia> markovBlanket(m, :α)
@model (β, x) begin
        α ~ StudentT(ν = 3.0)
        y ~ For(1:1000) do j
                Normal(μ = α + β * x[j])
            end
    end

######################################################

julia> dag = digraph(m)
SimpleDigraph{Symbol} (n=4, m=3)

julia> dag.N
Dict{Symbol, Set{Symbol}} with 4 entries:
  :α => Set([:y])
  :y => Set()
  :β => Set([:y])
  :x => Set([:y])

julia> dag.NN
Dict{Symbol, Set{Symbol}} with 4 entries:
  :α => Set()
  :y => Set([:α, :β, :x])
  :β => Set()
  :x => Set()

############################################################

x = randn(1000);
y = rand(m(;x));

julia> symlogdensity(m(;x) | (;y))
3.4166191036395746 - (0.5(5687.909333430344 + (4008.967498395781α) + (1282.559235689009β) + (1000(α^2)) + (985.752713011282(β^2)) - (173.80770668906146α*β))) - (2.0(log(3.0 + α^2)))


#############################################

julia> dynamicHMC(m(;x) | (;y))
1000-element TupleArray with schema (β = Float64, α = Float64)
(β = -0.835456 ± 0.0315286, α = -2.07694 ± 0.030521)


m1 = @model μ, σ begin
    x ~ Normal(μ,σ) 
    y ~ Normal(x,1) |> iid(20)
end

m2 = @model μ, σ begin
    z ~ Normal()
    x = σ * z + μ
    y ~ Normal(x,1) |> iid(20)
end
