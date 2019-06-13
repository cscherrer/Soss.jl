using DataStructures

using Soss: Let, Follows, Return, LineNumber
using MacroTools
using MacroTools: @q, striplines
using Parameters

export tocube
function tocube(m::Model)
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
        res = :($x = @. cdf($val, $u[:,$j]))
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

    f = gensym(:tocube)

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
