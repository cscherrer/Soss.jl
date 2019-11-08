abstract type AbstractChain end

abstract type AbstractStep end

plot(collect(Map(a -> next!(sobols)) |> Elbo(Cauchy(),Normal()), 1:10))
plot!(collect(Map(a -> next!(sobols)) |> Elbo(Cauchy(),Normal()), 1:1000))
plot!(collect(Map(a -> [rand()]) |> Elbo(Cauchy(),Normal()), 1:1000))
ylims!(-0.3,-0.1)




function elbo(p,q)
    xf = Map(a -> next!(sobols)) |> Elbo(p,q) # |> Converged()
    mapfoldl(xf, right, 1:500)
end

elbo(Cauchy(),Normal())

