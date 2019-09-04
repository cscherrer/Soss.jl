using GG

export rand

EmptyNTtype = NamedTuple{(),T} where T<:Tuple

function rand(m::Model{EmptyNTtype, B, D}) where {B,D}
    return rand(m,NamedTuple())    
end

@generated function rand(_m::Model{A,B,D}, _args::A) where {A,B,D} 
    type2model(_m) |> sourceRand |> loadvals(_args, NamedTuple())
end

export sourceRand
function sourceRand(m::Model{A,B,D}) where {A,B,D}
    _m = canonical(m)
    proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
    proc(_m, st::Sample)  = :($(st.x) = rand($(st.rhs)))
    proc(_m, st::Observe) = :($(st.x) = rand($(st.rhs)))
    proc(_m, st::Return)  = :(return $(st.rhs))
    proc(_m, st::LineNumber) = nothing

    vals = map(x -> Expr(:(=), x,x),variables(_m)) 

    wrap(kernel) = @q begin
        $kernel
        $(Expr(:tuple, vals...))
    end
    
    buildSource(_m, proc, wrap) |> flatten
end