export sourceRand

export argtuple
argtuple(m) = Expr(:tuple,arguments(m)...)


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

function sourceRand(m::Model)
    buildExpr!(ctx, st::Let)     = :($(st.name) = $(st.value))
    buildExpr!(ctx, st::Follows) = :($(st.name) = rand($(st.value)))
    buildExpr!(ctx, st::Return)  = :(return $(st.value))
    buildExpr!(ctx, st::LineNumber) = nothing

    buildSource(m, buildExpr!)
end