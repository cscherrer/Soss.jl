using Revise 
using Soss

m = @model begin
    n = 10 # number of samples
    m = 3 # reviewers for each example

    p_bad ~ Beta(1,10) |> iid(n)
    
    fpr ~ Beta(2,5) |> iid(m)
    tpr ~ Beta(5,2) |> iid(m)

    y ~ For(1:n, 1:m) do nj,mj
            Mix([Bernoulli(fpr[mj]), Bernoulli(tpr[mj])]
                , [1 - p_bad[nj], p_bad[nj]])
        end
end;

truth = rand(m());

@time result = dynamicHMC(m(), (y=truth.y,)) ;

# result = @time advancedHMC(m(), (y=truth.y,))

pairs(truth)
pairs(result)
