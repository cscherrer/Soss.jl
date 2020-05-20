using Revise

using Soss
# varying intercept, varying slope
vivs = @model subj,item  begin
    N = length(subj)
    J = maximum(subj)
    K = maximum(item)

    σu ~ HalfCauchy() |> iid(2)
    σw ~ HalfCauchy() |> iid(2)
    σe ~ HalfCauchy()
    u ~ For(1:2, 1:J) do i,j
            Normal(0.0, σu[i]) 
        end
    w ~ For(1:2, 1:J) do i,j
            Normal(0.0, σw[i]) 
        end
    β ~ Cauchy() |> iid(2)
    so ~ Bernoulli() |> iid(N)
    rt ~ For(1:N) do i 
        μ = (β[1] + u[1,subj[i]] + w[1,item[i]]
          + (β[2] + u[2,subj[i]] + w[2,item[i]]) * (so[i] ? 1 : -1)
            )
        LogNormal(μ,σe)
    end
end;

N = 10;
so = rand(16);
subj = repeat(1:4, inner=4);
item = repeat(1:4, outer=4);

truth = rand(vivs(so=so,subj=subj, item=item))

dynamicHMC(vivs(so=so,subj=subj, item=item), (rt = truth.rt,so=truth.so))

