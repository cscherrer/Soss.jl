export sourceRand

export argtuple
argtuple(m) = Expr(:tuple,arguments(m)...)

function sourceRand(m :: Model)
    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            qv = QuoteNode(v)
            prop = gensym(Symbol(v, "_prop"))
            if v ∈ m.args
                @q begin
                    $prop = rand($dist)
                    $prop == $v || return nothing
                end
            else
                @q begin
                    $v = rand($dist)
                    $prop = get(kwargs, $qv, $v)
                    # TODO: Swap == below with a comparison argument
                    # This would help for ABC etc
                    $prop == $v || return nothing
                    val = merge(val, ($v=$v,))
                end
            end
        else x
        end
    end

    for arg in arguments(m)
        expr = @q $arg = kwargs.$arg
        pushfirst!(body.args, expr)
    end

    @gensym rand
    #Wrap in a function to avoid global variables
    flatten(@q (
        function $rand(args...;kwargs...) 
            kwargs = Dict(kwargs)
            val = NamedTuple()
            $body
            val
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
    @eval $(sourceRand(m))
end


