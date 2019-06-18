using DataStructures

using Soss: Let, Follows, Return, LineNumber
using MacroTools
using MacroTools: @q, striplines
using Parameters

export tocube
function tocube(m::Model)

    m = canonical(m) |> dropLines

    dims = Dict([k => length(x) for (k,x) in pairs(rand(m))])
    dimTotal = sum(values(dims))

    function proc(m, st::Let; ctx=ctx)  
        x = st.x
        val = st.rhs
        :($x = @. $val)
    end

    function proc(m, st::Follows; ctx=ctx)
        x = st.x
        val = st.rhs
        u = ctx[:u]
        lo = ctx[:j][1] + 1
        hi = push!(ctx[:j],1,dims[x])

        res = @q begin
            $u[$lo:$hi,:] .= cdf.($val, $x)
        end
        res
    end
    
    proc(m, st::Return; ctx=ctx)  = :(return $(st.rhs))
    proc(m, st::LineNumber; ctx=ctx) = nothing

    ctx = Dict{Symbol, Any}()
    ctx[:j] = counter(Int)
    ctx[:m] = m
    @gensym u
    ctx[:u] = u

    body = Soss.buildSource(m, proc; ctx=ctx) |> striplines

    f = gensym(:tocube)

    argsExpr = Expr(:tuple,variables(m)...)

    MacroTools.flatten(@q (
        function $f(; kwargs...)
            $u = zeros($dimTotal,10)
            @unpack $argsExpr = kwargs
            $body
            return $u
        end
    ))
end
