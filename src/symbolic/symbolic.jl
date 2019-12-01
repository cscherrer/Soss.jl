using MacroTools: @q
using GeneralizedGenerated
import PyCall
using MLStyle

import SymPy
using SymPy: Sym, symbols, free_symbols


"""As type encoding a PyObject is unsafe without some hard
works with reference counting, we simply use a Julia proxy
to imitate the `sympy` module, e.g.,
    `sympy.attr = _pysympy.attr`
"""
struct PySymPyModule end
GeneralizedGenerated.NGG.@implement GeneralizedGenerated.NGG.Typeable{PySymPyModule}
const sympy = PySymPyModule()
Base.getproperty(::PySymPyModule, s::Symbol) = Base.getproperty(_pysympy, s)

const symfuncs = Dict()

_pow(a,b) = Base.:^(float(a),b)

function __init__()
    stats = PyCall.pyimport_conda("sympy.stats", "sympy")
    SymPy.import_from(stats)
    global stats = stats
    global _pysympy = SymPy.sympy



    # for dist in [:Normal, :Cauchy, :Laplace, :Beta, :Uniform]
    #     @eval begin
    #         function Distributions.$dist(μ::Sym, σ::Sym)
    #             println("Evaluating ",$dist, "(",μ," :: Sym, ", σ, " :: Sym)")
    #             stats.$dist(:dist, μ,σ) |> SymPy.density
    #         end

    #         Distributions.$dist(μ,σ) = $dist(promote(μ,σ)...)
    #     end
    # end



    # https://discourse.julialang.org/t/pyobjects-as-keys/26521/2
    merge!(symfuncs, Dict(
        sympy.log => Base.log
      , sympy.Pow => _pow
      , sympy.Abs => Base.abs
      , sympy.Indexed => getindex
    ))

    @eval begin
    @gg M function codegen(_::Type{M}, _m::Model, _args, _data) where M <: TypeLevel{Module}
        f = _codegen(type2model(_m))
        Expr(:let,
            Expr(:(=), :M, from_type(M)),
            :($f(_args, _data)))
    end
end

end


struct SymDist
    logpdf :: Function
end

logpdf(d::SymDist, x) = d.logpdf(sym(x))


Distributions.Bernoulli(p::Sym) = SymDist(y -> y * log(p) + (1-y) * log(1-p))

for dist in [:Bernoulli]
    @eval begin
        logpdf(d::$dist, x::Sym) = logpdf($dist(sym.(Distributions.params(d))...), x)

    end
end



"Half" distributions
for dist in [:Normal, :Cauchy]
    let half = Symbol(:Half, dist)
        @eval begin
            logpdf(d::$half, x::Sym) = 2 * logpdf($dist(0, sym.(d.σ)), x)
        end
    end
end

for dist in [:Normal, :Cauchy, :Laplace, :Beta, :Uniform]
    @eval begin
        function Distributions.$dist(μ::Sym, σ::Sym)
            stats.$dist(:dist, μ,σ) |> SymPy.density
        end

        Distributions.$dist(μ,σ) = $dist(promote(μ,σ)...)
    end
end


export sym
sym(s::Symbol) = sympy.IndexedBase(s, real=true)
sym(s) = Base.convert(Sym, s)
function sym(expr::Expr)
    @match expr begin
        Expr(:call, f, args...) => :($f($(map(sym,args)...)))
        :($x[$j]) => begin
            j = symbols(:j, cls=sympy.Idx)
            x = sympy.IndexedBase(x, real=true)
            return x[j]
        end
        _ => begin
                 @show expr
                 error("sym: Argument type not implemented")
             end
    end
end



# export symlogpdf
# # function symlogpdf(m::Model)
# #     m = canonical(m)

# #     result = @q begin
# #         ctx = Dict()

# #         ℓ = zero(Soss.Sym)
# #     end

# #     exprs = []

# #     for st in map(v -> findStatement(m,v), toposortvars(m))
# #         push!(exprs, symlogpdf(st))
# #     end


# #     append!(result.args, exprs)


# #     # result

# #     push!(result.args, :(ctx,ℓ))

# #     result

# #     # expandSums(ℓ)
# # end

# # function symlogpdf(st::Soss.Sample)
# #     d = st.rhs
# #     x = st.x
# #     :(ℓ += $(symlogpdf(d,x)))
# # end


# # function symlogpdf(st::Soss.Assign)
# #     val = st.rhs
# #     x = st.x
# #     :(ctx[$(QuoteNode(x))] = Expr(:$, $val))
# #     # :($x = $val)
# # end




# # function symlogpdf(d::Expr, x::Symbol)
# #     @match d begin
# #         :(iid($n,$dist)) => begin
# #             j = symbols(:j, cls=sympy.Idx)
# #             dist = sym(dist)
# #             x = sympy.IndexedBase(x)
# #             n = sym(n)
# #             :(Soss.sympy.Sum(logpdf($dist,$x[$j]), ($j,1,$n)))
# #         end

# #         :(For($f, (1:$n,))) => begin
# #             n = sym(n)
# #             @match f begin
# #                 :(($j,) -> begin $lineno; $dist end) => begin
# #                             j = symbols(j) # , cls=sympy.Idx)
# #                             # @show j
# #                             dist = sym(dist)
# #                             # @show dist
# #                             x = sympy.IndexedBase(x)
# #                             return :(Soss.sympy.Sum(logpdf($dist,$x[$j]), ($j,1,$n)))
# #                 end


# #                 f => begin
# #                     @show f
# #                     error("symlogpdf: bad argument")
# #                 end
# #             end

# #         end

# #         _ => :(logpdf($(sym(d)), $(sym(x))))
# #     end
# # end

export expandSums
function expandSums(s::Sym)
    s.args==() && return s
    if s.func==sympy.Sum
        s2 = expandSum(s.args...)
        # Maybe it didn't simplify and we're done
        s2 == s && return s2
        # Or not, and we recurse
        s = s2
    end
    newargs = [expandSums(t) for t in s.args]
    result = s.func(newargs...)
    # @show result - s
    # @assert sympy.simplify(result - s) == sym(0)
    return result
end


function expandSum(s::Sym, limits::Sym...)

    hasIdx(s) || return maybeSum(s, limits...)

    func = s.func
    args = s.args
    args == () && return maybeSum(s,limits...)

    if func == sympy.Add
        return func([expandSum(t, limits...) for t in args]...)
    elseif func == sympy.Mul
        return expandMulSum(args, limits...)
    else
        return sympy.Sum(s, limits...)
    end

end

# Expand a sum of a `Mul`
# Currently a greedy algorithm, may need to optimize later
function expandMulSum(factors::NTuple{N,Sym}, limits::Sym...) where {N}
    limits == () && return prod(factors)

    for fac in factors
        for lim in limits
            (ix, ixlo, ixhi) = lim.args
            if !insym(ix, fac)
                inSummand = prod(allbut(factors, fac))
                inSum = expandSum(inSummand, lim)
                outLims = allbut(limits, lim)
                return expandSum(fac*inSum, outLims...)
            end
        end
    end
    return maybeSum(prod(factors), limits...)
end

function atoms(s::Sym)
    s.func == sympy.Symbol && return [s]
    s.func == sympy.Idx && return [s]
    isempty(free_symbols(s)) && return []

    s.func == sympy.Sum && begin
        summand = s.args[1]
        ixs = [j.args[1] for j in s.args[2:end]]
        bounds = union([j.args[2:3] for j in s.args[2:end]]...)
        return setdiff(union(atoms(summand), atoms.(bounds)...), ixs)
    end 
    result = union(map(atoms, s.args)...)
    return result
end

function insym(j::Sym, s::Sym)
    j ∈ atoms(s)
    # for t in s.args
    #     if j==t || in(j,t)
    #         return true
    #     end
    # end
    # return false
end

hasIdx(s::Sym) = any(startswith.(getproperty.(Soss.atoms(s), :name), "_j"))

function allbut(tup, x)
    result = filter(collect(tup)) do v
        v ≠ x
    end
    tuple(result...)
end

# Force computation of sums that don't involve the index
function maybeSum(t::Sym, limits::Sym...)
    length(limits) > 0 || return t

    for lim in limits
        (ix, ixlo, ixhi) = lim.args
        insym(ix, t) || return maybeSum(t * (ixhi - ixlo + 1), allbut(limits, lim)...)
    end

    return sympy.Sum(t, limits...)
end

# # integrate(exp(ℓ), (sym(:μ), -oo, oo), (sym(:logσ),-oo,oo))
export marginal
function marginal(ℓ,v)
    f = ℓ.func
    f == sympy.Add || return ℓ
    newargs = filter(t -> sym(v) in t, collect(ℓ.args))
    foldl(+,newargs)
end

# marginal(m::Model, v) = marginal(m |> symlogpdf, v)

# # We should be able to reason about a marginal from its derivative
# export dmarginal
# function dmarginal(ℓ, v)
#     @as x ℓ begin
#         marginal(x,sym(v))
#         diff(x, sym(v))
#         expand(x)
#         sympy.collect(x, sym(v))
#     end
# end

# dmarginal(m::Model, v) = dmarginal(m |> symlogpdf, v)




# logpdf(Normal(sym(:μ),sym(:σ)), :x) |> SymPy.cse



# # macro symdist(n, dist)
# #     p = Expr(:tuple,gensym.(Symbol.(:p,1:n)))
# #     @q begin
# #         $dist($p)
# #     end
# # end
# # @macroexpand @symdist(4,Normal)

function symvar(st::Sample)
    st.rhs.args[1] ∈ [:For, :iid] && return IndexedBase(st.x)
    return sym(st.x)
end

export sourceSymlogpdf
function sourceSymlogpdf()
    function(_m::Model)
        function proc(_m, st :: Assign)
            # :($(st.x) = $(st.rhs))
            x = st.x
            xname = QuoteNode(x)
            :($x = $sympy.IndexedBase($xname))
        end

        function proc(_m, st :: Sample)
            @q begin
                _ℓ += symlogpdf($(st.rhs), $(st.x))
            end
        end
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        function wrap(kernel)
            q = @q begin
                _ℓ = 0.0
            end

            for x in variables(_m)
                xname = QuoteNode(x)
                push!(q.args, :($x = $sympy.IndexedBase($xname)))
            end

            for st in map(v -> findStatement(_m,v), toposortvars(_m))

                typeof(st) == Sample || continue
                x = st.x
                xname = QuoteNode(x)
                rhs = st.rhs
                xsym = ifelse(rhs.args[1] ∈ [:For, :iid]
                    , :($sympy.IndexedBase($xname))
                    , :($sym($xname))
                )
                # push!(q.args, :($x = $xsym))
            end

            @q begin
                $q
                $kernel
                return _ℓ
            end
        end



        buildSource(_m, proc, wrap) |> flatten
    end
end



For(f, θ::Sym) = For(f, (θ,))

function For(f::F, θ::NTuple{N,Sym}) where {F, N}
    For{F,NTuple{N,Sym},Sym,Sym}(f,θ)
end


# logpdf(d::For{F,N,T}, x::Array{Symbol, N}) where {F,N,T} = logpdf(d,sym.(x))

export symlogpdf
function symlogpdf(d::For{F,T,D,X}, x::Sym) where {F, N, J <: Union{Sym,Integer}, T <: NTuple{N,J}, D,  X}
    js = symbols.(Symbol.(:_j,1:N), cls=sympy.Idx)
    x = sympy.IndexedBase(x)
    result = symlogpdf(d.f(js...), x[js...])

    for k in N:-1:1
        result = sympy.Sum(result, (js[k], 1, d.θ[k]))
    end
    result
end

symlogpdf(d::iid, x::Sym) = symlogpdf(For(j -> d.dist, d.size), x)

symlogpdf(d::For{F,T,D,X}, x::Symbol) where {F,T,D,X} = symlogpdf(d,sym(x))

symlogpdf(d::Normal, x::Sym) = symlogpdf(Normal(sym(d.μ),sym(d.σ)), x)

symlogpdf(d::Cauchy, x::Sym) = symlogpdf(Cauchy(sym(d.μ),sym(d.σ)), x)


symlogpdf(d::Beta, x::Sym) = symlogpdf(Beta(sym(d.α),sym(d.β)), x)

# @generated function symlogpdf(d,x::Sym)
#     quote
#         args = propertynames(d)

#     end
# end

logpdf(d::Sym, x::Sym) = symlogpdf(d,x)

function symlogpdf(d::Sym, x::Sym)
    d.func
    result = d.pdf(x) |> log
    sympy.expand_log(result,force=true)
end

symlogpdf(d,x::Sym) = logpdf(d,x)

function symlogpdf(m::JointDistribution)
    return _symlogpdf(getmoduletypencoding(m.model), m.model)
end

function symlogpdf(m::Model)
    return _symlogpdf(getmoduletypencoding(m), m)
end

@gg M function _symlogpdf(_::Type{M}, _m::Model) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> canonical |> sourceSymlogpdf())
end


# # s = symlogpdf(normalModel).args[7].args[3]

# # export fexpr
# # fexpr = quote
# #     f = function(μ,σ,x)
# #         a = $(codegen(s))
# #         return a
# #     end
# # end

# # julia> i,j = sympy.symbols("i j", integer=True)
# # (i, j)

# # julia> x = sympy.IndexedBase("x")
# # x

# # julia> a = sympy.Sum(x[i], (i, 1, j))
# #   j
# #  ___
# #  ╲
# #   ╲   x[i]
# #   ╱
# #  ╱
# #  ‾‾‾
# # i = 1

# # julia> SymPy.walk_expression(a)
# # :(Sum(Indexed(IndexedBase(x), i), (:i, 1, :j)))


export tolatex
function tolatex(ℓ::SymPy.Sym)
    r = r"_j(?<num>\d+)"
    s = s"j_{\g<num>}"
    Base.replace(sympy.latex(ℓ), r => s)
end


export foldConstants
function foldConstants(s::Sym)
    s.func ==sympy.Integer && return s
    isempty(free_symbols(s)) && return Float64(SymPy.N(s))
    s.func == sympy.Sum && return sympy.Sum(foldConstants(s.args[1]), s.args[2:end]...)
    s.func == sympy.Indexed && return s
    s.func == sympy.IndexedBase && return s
    s.func == sympy.Symbol && return s
    newargs = foldConstants.(s.args)
    return s.func(newargs...)
end
