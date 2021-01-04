using MacroTools: @q
using GeneralizedGenerated
using MLStyle

using SymbolicUtils
using SymbolicUtils: Sym


import SpecialFunctions
using SpecialFunctions: logfactorial

using NestedTuples: schema

# Convert a type into the SymbolicUtils type we'll use to represent it
sym(T::Type) = :(Soss.Sym{$T})
# sym(::Type{T}) where {T <: Number} = Sym{Number}
sym(::Type{A}) where {T, N, A <: AbstractArray{T,N}} = :(Soss.SymArray{$T,$N})

sym(T::Type, s::Symbol) = :($(sym(T))($(QuoteNode(s))))

export sourceSymlogdensity
function sourceSymlogdensity(types)
    sym(s::Symbol) = Soss.sym(getproperty(types, s), s)

    function(_m::Model)
        function proc(_m, st :: Assign)
            x = st.x
            xname = QuoteNode(x)
            xsym = sym(x)
            return :($x = $xsym)
        end

        function proc(_m, st :: Sample)
            x = st.x
            xname = QuoteNode(x)
            xsym = sym(x)
            s = @q begin
                $x = $xsym
                _ℓ += logdensity($(st.rhs), $x)
            end
        end
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        function wrap(kernel)
            q = @q begin
                _ℓ = 0.0
            end

            for x in arguments(_m)
                xname = QuoteNode(x)
                xsym = sym(x)
                push!(q.args, :($x = $xsym))
            end

            @q begin
                $q
                $kernel
                return _ℓ
            end
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

export symlogdensity

symlogdensity(d,x::Sym) = logdensity(d,x)

function sourceSymlogdensity(cm::ConditionalModel{A,B,M}) where {A,B,M}
    trace = simulate(cm).trace
    vars = merge(trace, argvals(cm))
    return sourceSymlogdensity(schema(vars))(Model(cm))
end

function symlogdensity(cm::ConditionalModel{A,B,M}) where {A,B,M}
    trace = simulate(cm).trace
    vars = merge(trace, argvals(cm))
    s = _symlogdensity(M, Model(cm), vars)
    rewrite(s)
end


@gg M function _symlogdensity(_::Type{M}, _m::Model, _vars) where M <: TypeLevel{Module}
    Sym = SymbolicUtils.Sym
    types = schema(_vars)
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceSymlogdensity(types))
end



# For(f, θ::Sym) = For(f, (θ,))

# function For(f::F, θ::NTuple{N,Sym}) where {F, N}
#     For{F,NTuple{N,Sym},Sym,Sym}(f,θ)
# end


# logdensity(d::For{F,N,T}, x::Array{Symbol, N}) where {F,N,T} = logdensity(d,sym.(x))

# export symlogdensity
# function symlogdensity(d::For{F,T,D,X}, x::Sym) where {F, N, J <: Union{Sym,Integer}, T <: NTuple{N,J}, D,  X}
#     js = symbols.(Symbol.(:_j,1:N), cls=sympy.Idx)
#     x = sympy.IndexedBase(x)
#     result = symlogdensity(d.f(js...), x[js...])

#     for k in N:-1:1
#         result = sympy.Sum(result, (js[k], 1, d.θ[k]))
#     end
#     result
# end


# export tolatex
# function tolatex(ℓ::SymPy.Sym)
#     r = r"Idx\\left\(_j(?<num>\d+)\\right\)"
#     s = s"j_\g<num>"
#     x = Base.replace(sympy.latex(ℓ), r => s)
# end


# export foldConstants
# function foldConstants(s::Sym)
#     s.func ==sympy.Integer && return s
#     isempty(free_symbols(s)) && return Float64(SymPy.N(s))
#     s.func == sympy.Sum && return sympy.Sum(foldConstants(s.args[1]), s.args[2:end]...)
#     s.func == sympy.Indexed && return s
#     s.func == sympy.IndexedBase && return s
#     s.func == sympy.Symbol && return s
#     newargs = foldConstants.(s.args)
#     return s.func(newargs...)
# end




# @gg M function codegen(_::Type{M}, _m::Model, _args, _data) where M <: TypeLevel{Module}
#     f = _codegen(type2model(_m))
#     Expr(:let,
#         Expr(:(=), :M, from_type(M)),
#         :($f(_args, _data)))
# end


# Distributions.logpdf(d::SymDist, x) = d.logdensity(sym(x))


# export sym
# sym(s::Symbol) = sympy.symbols(s, real=true)
# sym(s) = Base.convert(Sym, s)
# function sym(expr::Expr)
#     @match expr begin
#         Expr(:call, f, args...) => :($f($(map(sym,args)...)))
#         :($x[$j]) => begin
#             j = symbols(:j, cls=sympy.Idx)
#             x = sympy.IndexedBase(x, real=true)
#             return x[j]
#         end
#         _ => begin
#                  @show expr
#                  error("sym: Argument type not implemented")
#              end
#     end
# end




# export expandSums
# function expandSums(s::Sym)
#     s.args==() && return s
#     if s.func==sympy.Sum
#         s2 = expandSum(s.args...)
#         # Maybe it didn't simplify and we're done
#         s2 == s && return s2
#         # Or not, and we recurse
#         s = s2
#     end
#     newargs = [expandSums(t) for t in s.args]
#     result = s.func(newargs...)
#     # @show result - s
#     # @assert sympy.simplify(result - s) == sym(0)
#     return result
# end


# function expandSum(s::Sym, limits::Sym...)

#     func = s.func
#     args = s.args
#     args == () && return maybeSum(s,limits...)


#     func == sympy.Add && return func([expandSum(t, limits...) for t in args]...)
#     func == sympy.Mul && return expandMulSum(args, limits...)

#     return maybeSum(s, limits...)

# end

# # Expand a sum of a `Mul`
# # Currently a greedy algorithm, may need to optimize later
# function expandMulSum(factors::NTuple{N,Sym}, limits::Sym...) where {N}
#     limits == () && return prod(factors)

#     p = sympy.expand_mul(prod(factors))
#     p.func == sympy.Mul || return expandSum(p, limits...)
#     factors = p.args
#     for fac in factors
#         for lim in limits
#             (ix, ixlo, ixhi) = lim.args
#             if ix ∉ atoms(fac)
#                 inSummand = prod(allbut(factors, fac))
#                 inSum = expandSum(inSummand, lim)
#                 outLims = allbut(limits, lim)
#                 return expandSum(fac*inSum, outLims...)
#             end
#         end
#     end
#     return maybeSum(prod(factors), limits...)
# end



# function allbut(tup, x)
#     result = filter(collect(tup)) do v
#         v ≠ x
#     end
#     tuple(result...)
# end

# # Force computation of sums that don't involve the index
# function maybeSum(t::Sym, limits::Sym...)
#     length(limits) > 0 || return t

#     for lim in limits
#         (ix, ixlo, ixhi) = lim.args
#         ix ∈ atoms(t) || begin
#             return maybeSum(t * (ixhi - ixlo + 1), allbut(limits, lim)...)
#         end
#     end

#     return sympy.Sum(t, limits...)
# end

# # # integrate(exp(ℓ), (sym(:μ), -oo, oo), (sym(:logσ),-oo,oo))
# export marginal
# function marginal(ℓ,v)
#     f = ℓ.func
#     f == sympy.Add || return ℓ
#     newargs = filter(t -> sym(v) in atoms(t), collect(ℓ.args))
#     foldl(+,newargs)
# end

# export score
# score(ℓ::Sym, v) = diff(ℓ, sym(v))

# score(m::Model, v) = score(symlogdensity(m), v)

# marginal(m::Model, v) = marginal(m |> symlogdensity, v)

# symvar(st) = :($sympy.IndexedBase($(st.x)))

# function symvar(st::Sample)
#     st.rhs.args[1] ∈ [:For, :iid] && return :($sympy.IndexedBase($(st.x)))
#     return :($sym($(st.x)))
# end


# sourceSymlogdensity(m::Model) = sourceSymlogdensity()(m)
