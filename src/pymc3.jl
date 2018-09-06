

lookup = Dict(
    :Normal => (
        pmcall=:(pm.Normal()), 
        pmargs=[:mu,:sd])
)


function pymc3(expr) 
    result = []
    if @capture(expr, v_ ~ dist_)
        if @capture(dist, dname_(args__))
            lhs = v
            dinfo = lookup[dname]
            rhs = dinfo.pmcall
            push!(rhs.args, "$v")
            for (jlarg,pmarg) in zip(args,dinfo.pmargs)
                push!(rhs.args, :($pmarg = $jlarg))
            end
        :($lhs = $rhs)
        end
    else expr 
    end
end

ex = :(x ~ Normal(μ, σ))
pymc3(ex)
