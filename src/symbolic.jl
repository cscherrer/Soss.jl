using MacroTools: @q
using SymPy
import PyCall
using MLStyle
using Lazy


# stats = PyCall.pyimport_conda("sympy.stats", "sympy")
# import_from(stats)

sym(s::Symbol) = SymPy.symbols(s)
sym(s) = Base.convert(Sym, s)
function sym(expr::Expr) 
    @match expr begin
        Expr(:call, f, args...) => :($f($(map(sym,args)...)))
        _                       => error("sym: Argument type not implemented")
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
    d = st.value
    x = st.name
    :(ℓ += $(symlogpdf(d,x)))
end


function symlogpdf(st::Soss.Let)
    val = st.value
    x = st.name
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
    sum(newargs)
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