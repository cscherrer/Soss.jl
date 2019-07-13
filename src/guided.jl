
function sourceWithGuide(m::Model, g::Model)
    m = canonical(m)
    g = canonical(g)
    
    proc(m, st::Let)     = :($(st.x) = $(st.rhs))
    proc(m, st::Follows) = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    body = buildSource(m, proc) |> striplines
    
    argsExpr = Expr(:tuple,freeVariables(m)...)

    stochExpr = begin
        vals = map(stochastic(m)) do x Expr(:(=), x,x) end
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