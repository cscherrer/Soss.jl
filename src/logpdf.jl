using Pkg
Pkg.activate(".")
using Revise
using Soss
linReg1D

using MacroTools: @q
using SymPy
import PyCall
using MLStyle
using Lazy

sym(s::Symbol) = SymPy.symbols(s)

sym(s) = Base.convert(Sym, s)

function sym(expr::Expr)
    @match expr begin
        :($x = $val)            => :(ctx[$x] = sym($val))
        :($x ~ $d)              => :(ℓ += $(symlogpdf(d,x)))
        Expr(:call, f, args...) => :($f($(map(sym,args)...)))
        _                       => expr
    end
end

function symbolic(expr)
    quote
        ctx = Dict()
        ℓ = zero(Sym)
        $(sym(expr))
        (ctx, ℓ)
    end
end

function symbolic(m::Model)
    result = @q begin
        ctx = Dict()
        ℓ = zero(Sym)
    end

    exprs = @as x m begin
        canonical(x)
        dropLines(x)
        x.body
        Soss.convert.(Expr,x)
        sym.(x)
    end

    append!(result.args, exprs)

    push!(result.args, :(ℓ))
    result
end


macro symbolic(expr)
    symbolic(expr) |> esc
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
function in(j::Sym, s::Sym)
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

# s = sym(canonical(:(x ~ Normal(μ, σ) |> iid(10)))).args[2] |> eval |> expandSums

normalModel |> symbolic |> eval |> expandSums