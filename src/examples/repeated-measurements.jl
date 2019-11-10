using Revise 
using Soss

m = @model begin
    n = 10 # number of samples
    m = 10 # reviewers for each example

    p_bad ~ Beta(1,3) |> iid(n)
    
    fpr ~ Beta(2,5) |> iid(m)
    tpr ~ Beta(5,2) |> iid(m)

    y ~ For(n, m) do nj,mj
            Mix([Bernoulli(fpr[mj]), Bernoulli(tpr[mj])]
                , [1 - p_bad[nj], p_bad[nj]])
        end
end;

using Random
truth = rand(m());
symlogpdf(m())

@time logpdf(m(),truth, codegen)
@time logpdf(m(),truth, codegen)



codegen(m(),truth)



logpdf(m(), merge(truth, (p_bad=shuffle(truth.p_bad),)))


@time result = dynamicHMC(m(), (y=truth.y,), codegen) ;

# result = @time advancedHMC(m(), (y=truth.y,))

pairs(truth)
result |> particles |> pairs

