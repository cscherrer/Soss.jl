export makeRand

# TODO: Make this work for other-than-Int sizes, and precompute instead of push!
function makeRand(m :: Model)
    myArgs = Expr(:tuple,arguments(m)...)

    # if ~isempty(observed(m))
    #     return logWeightedRand(m, N)
    # end

    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            @q begin
                par.$v = rand($dist)
                val = merge(val, ($v=$v,))
            end
        else x
        end
    end

    #Wrap in a function to avoid global variables
    flatten(@q par -> begin
            val = NamedTuple()
            $body
            val
    end)
end

function rand(m :: Model, par)
    f = makeRand(m) |> eval
    Base.invokelatest(f,par)
end

rand(m :: Model, N :: Int) = begin

end

export logWeightedRand
function logWeightedRand(m :: Model, N :: Int)

    body = postwalk(m.body) do x
        if @capture(x, v_ ~ dist_)
            @q begin
                $v = rand($dist)
                val = merge(val, ($v=$v,))
            end
        elseif @capture(x, v_ ⩪ dist_)
            @q ℓ += logpdf($dist, $v)
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
