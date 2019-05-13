export sourceRand

export argtuple
argtuple(m) = Expr(:tuple,arguments(m)...)

function sourceRand(m :: Model)
    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            qv = QuoteNode(v)
            @q ($v = rand($dist))
        else x
        end
    end

    @gensym rand

    argsExpr = Expr(:tuple,arguments(m)...)

    # Pack stochastic variables into a NamedTuple
    stochExpr = begin
        vals = map(stochastic(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    #Wrap in a function to avoid global variables
    flatten(@q (
        function $rand(args...;kwargs...) 
            @unpack $argsExpr = kwargs
            # kwargs = Dict(kwargs)
            $body
            $stochExpr
        end
    ))
end



export logWeightedRand
function logWeightedRand(m :: Model, N :: Int)

    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            @q begin
                $v = rand($dist)
                val = merge(val, ($v=$v,))
            end
        else x
        end
    end

    #Wrap in a function to avoid global variables
    result = @q () -> begin
        ans = []
        for n in 1:$N
            ℓ = 0.0
            val = NamedTuple()
            $body
            push!(ans,Weighted(val,ℓ))
        end
        ans
    end

    return Base.invokelatest(eval(result))

end


export makeRand
function makeRand(m :: Model)
    fpre = @eval $(sourceRand(m))
    f(;kwargs...) = Base.invokelatest(fpre; kwargs...)
end

export rand
rand(m::Model; kwargs...) = makeRand(m)(;kwargs...)
