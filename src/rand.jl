export makeRand

export argtuple
argtuple(m) = Expr(:tuple,arguments(m)...)

function makeRand(m :: Model)

    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            @q begin
                $v = rand($dist)
                val = merge(val, ($v=$v,))
            end
        else x
        end
    end

    for arg in arguments(m)
        expr = @q $arg = kwargs.$arg
        pushfirst!(body.args, expr)
    end

    #Wrap in a function to avoid global variables
    flatten(@q kwargs -> begin
            val = NamedTuple()
            $body
            val
    end)
end

function rand(m :: Model,n::Int)
    f = @eval $(makeRand(m))
    println(typeof(f))
    go(x) = Base.invokelatest(f,x)
    go
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

# If no number is given, just take the first (and only) element from a singleton array
function rand(m :: Model)
    rand(m,1)[1]
end

function rand(n::Int)
    x -> rand(x,n)
end
