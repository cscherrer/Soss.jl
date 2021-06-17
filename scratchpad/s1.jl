using Soss

m = @model begin
    x ~ Normal() |> iid(2)
    xxt = x * x'
end;

s = rand(m(), 1000)

