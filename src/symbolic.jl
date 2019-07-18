using MacroTools: @q
using SymPy
import PyCall
using MLStyle
using Lazy


Base.log1p(s::Sym) = log(1 + s)

# stats = PyCall.pyimport_conda("sympy.stats", "sympy")
# import_from(stats)

export sym
sym(s::Symbol) = SymPy.symbols(s)
sym(s) = Base.convert(Sym, s)
function sym(expr::Expr) 
    @match expr begin
        Expr(:call, f, args...) => :($f($(map(sym,args)...)))
        _ => begin
                 @show expr
                 error("sym: Argument type not implemented")
             end
    end
end

export symlogpdf
function symlogpdf(m::Model)
    result = @q begin
        ctx = Dict()
        ℓ = zero(Sym)
    end

    exprs = @as x m begin
        canonical(x)
        dropLines(x)
        x.body
        symlogpdf.(x)
    end

    append!(result.args, exprs)

    push!(result.args, :(ℓ))
    eval(result) |> expandSums
end

function symlogpdf(st::Soss.Follows)
    d = st.rhs
    x = st.x
    :(ℓ += $(symlogpdf(d,x)))
end


function symlogpdf(st::Soss.Let)
    val = st.rhs
    x = st.x
    :(ctx[$(QuoteNode(x))] = $(sym(val)))
end




function symlogpdf(d::Expr, x::Symbol)
    @match d begin
        :(iid($n,$dist)) => begin
                j = symbols(:j, cls=sympy.Idx)
                dist = sym(dist)
                x = sympy.IndexedBase(x)
                :(sympy.Sum(logpdf($dist,$x[$j]), ($j,1,$n)))
            end

        # :(For($f, $))
        _ => :(logpdf($(sym(d)), $(sym(x))))
    end
end


function expandSums(s::Sym)
    s.args==() && return s
    if s.func==sympy.Sum
        s2 = expandSum(s)
        # Maybe it didn't simplify and we're done
        s2 == s && return s2
        # Or not, and we recurse
        s = s2
    end
    newargs = [expandSums(t) for t in s.args]
    s.func(newargs...)
end

function expandSum(s::Sym)
    @assert s.func == sympy.Sum
    sfunc = s.args[1].func
    sargs = s.args[1].args
    limits = s.args[2]
    if sfunc in [sympy.Add, sympy.Mul]
        return sfunc([maybesum(t, limits) for t in sargs]...)
    else
        return s
    end

end

import Base.in
function Base.in(j::Sym, s::Sym)
    for t in s.args
        if j==t || in(j,t)
            return true
        end
    end
    return false
end

function maybesum(t::Sym, limits::Sym)
    j = limits.args[1]
    thesum = sympy.Sum(t, limits)
    ifelse(j in t, thesum, thesum.doit())
end

# integrate(exp(ℓ), (sym(:μ), -oo, oo), (sym(:logσ),-oo,oo))
export marginal
function marginal(ℓ,v)
    f = ℓ.func
    f == sympy.Add || return ℓ
    newargs = filter(t -> sym(v) in t, collect(ℓ.args))
    foldl(+,newargs)
end

marginal(m::Model, v) = marginal(m |> symlogpdf, v)

# We should be able to reason about a marginal from its derivative
export dmarginal
function dmarginal(ℓ, v)
    @as x ℓ begin
        marginal(x,sym(v))
        diff(x, sym(v))
        expand(x)
        sympy.collect(x, sym(v))
    end
end

dmarginal(m::Model, v) = dmarginal(m |> symlogpdf, v)

# https://discourse.julialang.org/t/pyobjects-as-keys/26521/2
const symfuncs = Dict()
function __init__()
    merge!(symfuncs, Dict(
          sympy.log => log
        , sympy.Pow => :^
        , sympy.Abs => abs
        , sympy.Indexed => getindex
    ))
end


export codegen
function codegen(s::Sym)
    s.func == sympy.Add && begin
        @gensym add
        ex = @q begin 
            $add = 0.0
        end
        for arg in s.args
            t = codegen(arg)
            push!(ex.args, :($add += $t))
        end
        push!(ex.args, add)
        # @show ex
        return ex
    end


    s.func == sympy.Mul && begin
        @gensym mul
        ex = @q begin 
            $mul = 1.0
        end
        for arg in s.args
            t = codegen(arg)
            push!(ex.args, :($mul *= $t))
        end
        push!(ex.args, mul)
        return ex
    end

    # s.func == sympy.Sum && begin

    # end

    s.func ∈ keys(symfuncs) && begin
        @gensym symfunc
        argnames = gensym.("arg" .* string.(1:length(s.args)))
        argvals = codegen.(s.args)
        ex = @q begin end
        for (k,v) in zip(argnames, argvals)
            push!(ex.args, :($k = $v))
        end
        f = symfuncs[s.func]
        push!(ex.args, :($symfunc = $f($(argnames...))))
        push!(ex.args, symfunc)
        return ex
    end

    s.func == sympy.Sum && begin
        @gensym sum
        @gensym Δsum
        @gensym lo 
        @gensym hi
        
        summand = codegen(s.args[1])
        (ix, ixlo, ixhi) = s.args[2].args

        ex = @q begin
            $sum = 0.0
            $lo = $(codegen(ixlo))
            $hi = $(codegen(ixhi))
            for $(codegen(ix)) = $lo:$hi
                $Δsum = $summand
                $sum += $Δsum
            end
            $sum
        end

        return ex
    end
    
    s.func == sympy.Symbol && return Symbol(string(s))
    s.func == sympy.Idx && return Symbol(string(s))        
    s.func == sympy.IndexedBase && return Symbol(string(s))

    SymPy.is_real(s) && begin
        return N(s)
    end


    @show s.func
    error("codegen")
end

codegen(s::AbstractFloat) = s