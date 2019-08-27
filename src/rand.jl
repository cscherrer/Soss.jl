using GG

nt = NamedTuple{(),Tuple{}}

export rand

rand(m) = _rand(m,nt,nt)

@generated function _rand(_m::Model{A,B,D}, _args::A, _data::D) where {A,B,D} 
    type2model(_m) |> sourceRand
end

export sourceRand
function sourceRand(m::Model{A,B,D}) where {A,B,D}
    _m = canonical(m)
    proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
    proc(_m, st::Sample)  = :($(st.x) = rand($(st.rhs)))
    proc(_m, st::Observe) = :($(st.x) = rand($(st.rhs)))
    proc(_m, st::Return)  = :(return $(st.rhs))
    proc(_m, st::LineNumber) = nothing

    stochExpr = begin
        vals = map(x -> Expr(:(=), x,x),variables(_m)) 
        Expr(:tuple, vals...)
    end

    wrap(kernel) = @q begin
        $kernel
        $stochExpr
    end
    
    buildSource(_m, proc, wrap) |> flatten
end