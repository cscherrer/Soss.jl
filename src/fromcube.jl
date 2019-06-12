using DataStructures

using Soss: Let, Follows, Return, LineNumber
using MacroTools
using MacroTools: @q, striplines
using Parameters

export fromcube
function fromcube(m::Model)
    function buildExpr!(ctx, st::Let)  
        x = st.name
        val = st.value
        :($x = @. $val)
    end

    function buildExpr!(ctx, st::Follows)
        x = st.name
        val = st.value
        u = ctx[:u]
        j = push!(ctx[:j],1)
        res = :($x = @. quantile($val, $u[:,$j]))
        res
    end
    buildExpr!(ctx, st::Return)  = :(return $(st.value))
    buildExpr!(ctx, st::LineNumber) = nothing

    ctx = Dict{Symbol, Any}()
    ctx[:j] = counter(Int)
    ctx[:m] = m
    @gensym u
    ctx[:u] = u

    m = canonical(m) |> dropLines

    body = Soss.buildSource(ctx, buildExpr!) |> striplines

    f = gensym(:fromcube)

    argsExpr = argtuple(m)

    returnexp = begin
        vals = map(stochastic(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end

    MacroTools.flatten(@q (
        function $f($u; kwargs...)
            @unpack $argsExpr = kwargs
            $body
            $returnexp
        end
    ))
end


function fromcubeExample()
    m = @model begin
        x ~ Normal(0,1)
        y ~ Cauchy(20 * x^2, 1)
    end

    f = fromcube(m) |> eval

    using Sobol
    s = SobolSeq(2)
    p = hcat([next!(s) for i = 1:1024]...)'
    dat = f(p)
    scatter(dat.x, dat.y)
end