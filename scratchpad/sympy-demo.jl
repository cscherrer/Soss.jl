import PyCall, SymPy

using MLStyle

stats = PyCall.pyimport_conda("sympy.stats", "sympy")
SymPy.import_from(stats)


sym(x) = SymPy.symbols(x)

macro ℓ(expr)
    args = @match expr begin
        Expr(head, args...) => args
    end
    d = args[1]
    ps = args[2:end]
    quote
        L = SymPy.density(stats.$d(:foo, sym.($ps)...)).pdf(sym(:x))
        SymPy.sympy.expand_log(log(L), force=true)
    end
end

@ℓ Cauchy(μ, σ)
