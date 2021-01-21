
using SymbolicUtils
using SymbolicUtils: Symbolic, term


function symify(s::Symbolic)
    p(s) = s isa UnitRange
    r = @rule ~x::p => term(UnitRange, getproperty(~x, :start), getproperty(~x, :stop); type=UnitRange{Int})
    RW.Prewalk(RW.PassThrough(r))(s)
end

function symify(expr::Expr)
    function branch(head, newargs)
        expr = Expr(head, newargs...)
        @match expr begin
            Expr(:call, :(:), a, b) => :(Soss.term(UnitRange, $a, $b; type=UnitRange))
            # TODO: Make slices work
            :($x[$(i...)]) => :(Soss.term(getindex, $x, $(i...); type=eltype($x)))
            _ => expr
        end
    end
    
    return foldall(identity, branch)(expr)
end

function symify(m :: Model)
    args = m.args :: Vector{Symbol}
    vals  = map(symify, m.vals) 
    dists = map(symify, m.dists) 
    retn = m.retn  
    Model(getmodule(m), args, vals, dists, retn)
end    
