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

function rand(m::Model, n::Int64; kwargs...)
    r = makeRand(m)(;kwargs...)

end

function sourceRand(m::Model)
    buildExpr!(ctx, st::Let)     = :($(st.name) = $(st.value))
    buildExpr!(ctx, st::Follows) = :($(st.name) = rand($(st.value)))
    buildExpr!(ctx, st::Return)  = :(return $(st.value))
    buildExpr!(ctx, st::LineNumber) = nothing

    body = buildSource(m, buildExpr!) |> striplines
    
    argsExpr = argtuple(m)

    stochExpr = begin
        vals = map(stochastic(linReg1D)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    
    @gensym rand
    
    flatten(@q (
        function $rand(args...;kwargs...) 
            @unpack $argsExpr = kwargs
            # kwargs = Dict(kwargs)
            $body
            $stochExpr
        end
    ))

end