using MacroTools: @q
using GeneralizedGenerated
import PyCall
using MLStyle

import SymPy
using SymPy: Sym, symbols, free_symbols
import SpecialFunctions
using SpecialFunctions: logfactorial

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
    logdensity :: Function
end

logdensity(d::SymDist, x) = d.logdensity(sym(x))


# julia> logdensity(SymPy.density(Soss.stats.Poisson(:Poisson,sym(:λ))), sym(:x))
# x⋅log(λ) - λ - log(x!)

SpecialFunctions.logfactorial(x::Sym) = sympy.loggamma(x+1)

Distributions.Poisson(λ::Sym) = SymDist(x -> x * log(λ) - λ - logfactorial(x))
Distributions.Bernoulli(p::Sym) = SymDist(y -> y * log(p) + (1-y) * log(1-p))

for dist in [:Bernoulli, :Poisson]
    @eval begin
        logdensity(d::$dist, x::Sym) = logdensity($dist(sym.(Distributions.params(d))...), x)
    end
end



# "Half" distributions
for dist in [:Normal, :Cauchy]
    let half = Symbol(:Half, dist)
        @eval begin
            logdensity(d::$half, x::Sym) = 2 * logdensity($dist(0, sym.(d.σ)), x)
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
sym(s::Symbol) = sympy.symbols(s, real=true)
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

    func = s.func
    args = s.args
    args == () && return maybeSum(s,limits...)


    func == sympy.Add && return func([expandSum(t, limits...) for t in args]...)
    func == sympy.Mul && return expandMulSum(args, limits...)

    return maybeSum(s, limits...)

end

# Expand a sum of a `Mul`
# Currently a greedy algorithm, may need to optimize later
function expandMulSum(factors::NTuple{N,Sym}, limits::Sym...) where {N}
    limits == () && return prod(factors)

    p = sympy.expand_mul(prod(factors))
    p.func == sympy.Mul || return expandSum(p, limits...)
    factors = p.args
    for fac in factors
        for lim in limits
            (ix, ixlo, ixhi) = lim.args
            if ix ∉ atoms(fac)
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
        ix ∈ atoms(t) || begin
            return maybeSum(t * (ixhi - ixlo + 1), allbut(limits, lim)...)
        end
    end

    return sympy.Sum(t, limits...)
end

# # integrate(exp(ℓ), (sym(:μ), -oo, oo), (sym(:logσ),-oo,oo))
export marginal
function marginal(ℓ,v)
    f = ℓ.func
    f == sympy.Add || return ℓ
    newargs = filter(t -> sym(v) in atoms(t), collect(ℓ.args))
    foldl(+,newargs)
end

export score
score(ℓ::Sym, v) = diff(ℓ, sym(v))

score(m::Model, v) = score(symlogdensity(m), v)

marginal(m::Model, v) = marginal(m |> symlogdensity, v)

symvar(st) = :($sympy.IndexedBase($(st.x)))

function symvar(st::Sample)
    st.rhs.args[1] ∈ [:For, :iid] && return :($sympy.IndexedBase($(st.x)))
    return :($sym($(st.x)))
end
    

export sourceSymlogdensity
function sourceSymlogdensity()
    function(_m::Model)
        function proc(_m, st :: Assign)
            x = st.x
            xname = QuoteNode(x)
            return :($x = $sympy.IndexedBase($xname))
        end

        function proc(_m, st :: Sample)
            s = :(_ℓ += symlogdensity($(st.rhs), $(symvar(st))))
            end
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        function wrap(kernel)
            q = @q begin
                _ℓ = 0.0
            end

            for x in arguments(_m)
                xname = QuoteNode(x)
                xsym = :($sympy.IndexedBase($xname))
                push!(q.args, :($x = $xsym))
            end

            for st in map(v -> findStatement(_m,v), toposort(_m))

                typeof(st) == Sample || continue
                x = st.x
                xname = QuoteNode(x)
                rhs = st.rhs
                xsym = ifelse(rhs.args[1] ∈ [:For, :iid]
                    , :($sympy.IndexedBase($xname))
                    , :($sym($xname))
                )
                push!(q.args, :($x = $xsym))
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


# logdensity(d::For{F,N,T}, x::Array{Symbol, N}) where {F,N,T} = logdensity(d,sym.(x))

export symlogdensity
function symlogdensity(d::For{F,T,D,X}, x::Sym) where {F, N, J <: Union{Sym,Integer}, T <: NTuple{N,J}, D,  X}
    js = symbols.(Symbol.(:_j,1:N), cls=sympy.Idx)
    x = sympy.IndexedBase(x)
    result = symlogdensity(d.f(js...), x[js...])

    for k in N:-1:1
        result = sympy.Sum(result, (js[k], 1, d.θ[k]))
    end
    result
end

symlogdensity(d::iid, x::Sym) = symlogdensity(For(j -> d.dist, d.size), x)

symlogdensity(d::For{F,T,D,X}, x::Symbol) where {F,T,D,X} = symlogdensity(d,sym(x))

symlogdensity(d::Normal, x::Sym) = symlogdensity(Normal(sym(d.μ),sym(d.σ)), x)

symlogdensity(d::Cauchy, x::Sym) = symlogdensity(Cauchy(sym(d.μ),sym(d.σ)), x)


symlogdensity(d::Beta, x::Sym) = symlogdensity(Beta(sym(d.α),sym(d.β)), x)

symlogdensity(d::Poisson, x::Sym) = symlogdensity(Poisson(sym(d.λ)), x)

logdensity(d::Sym, x::Sym) = symlogdensity(d,x)

function symlogdensity(d::Sym, x::Sym)
    d.func
    result = d.pdf(x) |> log
    sympy.expand_log(result,force=true)
end

symlogdensity(d,x::Sym) = logdensity(d,x)

function symlogdensity(d::JointDistribution, simplify=true)
    symlogdensity(d.model)
end

function symlogdensity(m::Model, simplify=true)
    s = _symlogdensity(getmoduletypencoding(m), m)
    simplify && return foldConstants(expandSums(s))
    return s
end

@gg M function _symlogdensity(_::Type{M}, _m::Model) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> canonical |> sourceSymlogdensity())
end



export tolatex
function tolatex(ℓ::SymPy.Sym)
    r = r"Idx\\left\(_j(?<num>\d+)\\right\)"
    s = s"j_\g<num>"
    x = Base.replace(sympy.latex(ℓ), r => s)
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
