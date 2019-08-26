using GG

export rand
@generated function rand(m::Model{T} where T) 
    type2model(m) |> sourceRand
end

export sourceRand
function sourceRand(m::Model{T} where T)
    m = canonical(m)
    proc(m, st::Assign)  = :($(st.x) = $(st.rhs))
    proc(m, st::Sample)  = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Observe) = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    stochExpr = begin
        vals = map(x -> Expr(:(=), x,x),variables(m)) 
        Expr(:tuple, vals...)
    end

    wrap(kernel) = @q begin
        $kernel
        $stochExpr
    end
    
    buildSource(m, proc, wrap) |> flatten
end