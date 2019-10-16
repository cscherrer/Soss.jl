using MacroTools: @q
import PyCall
using MLStyle
# using Lazy

import SymPy
using SymPy: Sym, sympy, symbols

stats = PyCall.pyimport_conda("sympy.stats", "sympy")
SymPy.import_from(stats)


export sym
sym(s::Symbol) = SymPy.symbols(s)
sym(s) = Base.convert(Sym, s)
function sym(expr::Expr) 
    @match expr begin
        Expr(:call, f, args...) => :($f($(map(sym,args)...)))
        :($x[$j]) => begin
            j = symbols(:j, cls=sympy.Idx)
            x = sympy.IndexedBase(x)
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


# function expandSums(s::Sym)
#     s.args==() && return s
#     if s.func==sympy.Sum
#         s2 = expandSum(s)
#         # Maybe it didn't simplify and we're done
#         s2 == s && return s2
#         # Or not, and we recurse
#         s = s2
#     end
#     newargs = [expandSums(t) for t in s.args]
#     s.func(newargs...)
# end

# function expandSum(s::Sym)
#     # println("expandSum")
#     # @show s
#     # println()
#     @assert s.func == sympy.Sum
#     sfunc = s.args[1].func
#     sargs = s.args[1].args
#     limits = s.args[2]
#     ix = limits.args[1]
#     if sfunc == sympy.Add
#         return sfunc([maybesum(t, limits) for t in sargs]...)
#     elseif sfunc == sympy.Mul
#         factors = sargs
#         constants = [fac for fac in factors if !(ix in fac)]
#         newconst = foldl(*,constants)
#         newfacs = foldl(*,setdiff(factors, constants))
#         newsum = sympy.Sum(newfacs, limits)
#         return newconst * newsum
#     else
#         return s
#     end

# end

# import Base.in
# function Base.in(j::Sym, s::Sym)
#     for t in s.args
#         if j==t || in(j,t)
#             return true
#         end
#     end
#     return false
# end

# function maybesum(t::Sym, limits::Sym)
#     # println("maybeSum")
#     # @show t,limits
#     # println()
#     j = limits.args[1]
#     thesum = sympy.Sum(t, limits)
#     ifelse(j in t, thesum, thesum.doit())
# end

# # integrate(exp(ℓ), (sym(:μ), -oo, oo), (sym(:logσ),-oo,oo))
# export marginal
# function marginal(ℓ,v)
#     f = ℓ.func
#     f == sympy.Add || return ℓ
#     newargs = filter(t -> sym(v) in t, collect(ℓ.args))
#     foldl(+,newargs)
# end

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

# # https://discourse.julialang.org/t/pyobjects-as-keys/26521/2
# # const symfuncs = Dict()
# # function __init__()
# #     merge!(symfuncs, Dict(
# #           sympy.log => log
# #         , sympy.Pow => :^
# #         , sympy.Abs => abs
# #         , sympy.Indexed => getindex
# #     ))
# # end


# export codegen
# function codegen(s::Sym)
#     s.func == sympy.Add && begin
#         @gensym add
#         ex = @q begin 
#             $add = 0.0
#         end
#         for arg in s.args
#             t = codegen(arg)
#             push!(ex.args, :($add += $t))
#         end
#         push!(ex.args, add)
#         # @show ex
#         return ex
#     end


#     s.func == sympy.Mul && begin
#         @gensym mul
#         ex = @q begin 
#             $mul = 1.0
#         end
#         for arg in s.args
#             t = codegen(arg)
#             push!(ex.args, :($mul *= $t))
#         end
#         push!(ex.args, mul)
#         return ex
#     end

#     # s.func == sympy.Sum && begin

#     # end

#     s.func ∈ keys(symfuncs) && begin
#         # @show s
#         @gensym symfunc
#         argnames = gensym.("arg" .* string.(1:length(s.args)))
#         argvals = codegen.(s.args)
#         ex = @q begin end
#         for (k,v) in zip(argnames, argvals)
#             push!(ex.args, :($k = $v))
#         end
#         f = symfuncs[s.func]
#         push!(ex.args, :($symfunc = $f($(argnames...))))
#         push!(ex.args, symfunc)
#         return ex
#     end

#     s.func == sympy.Sum && begin
#         @gensym sum
#         @gensym Δsum
#         @gensym lo 
#         @gensym hi
        
#         summand = codegen(s.args[1])
#         (ix, ixlo, ixhi) = s.args[2].args

#         ex = @q begin
#             $sum = 0.0
#             $lo = $(codegen(ixlo))
#             $hi = $(codegen(ixhi))
#             @inbounds @simd for $(codegen(ix)) = $lo:$hi
#                 $Δsum = $summand
#                 $sum += $Δsum
#             end
#             $sum
#         end

#         return ex
#     end
    
#     s.func == sympy.Symbol && return Symbol(string(s))
#     s.func == sympy.Idx && return Symbol(string(s))        
#     s.func == sympy.IndexedBase && return Symbol(string(s))

#     # @show s
#     SymPy.is_real(s) && begin
#         return SymPy.N(s)
#     end


#     @show s.func
#     error("codegen")
# end

# codegen(s::AbstractFloat) = s

# # export codegen
# function codegen(m::Model)
#     code = codegen(symlogpdf(m))
#     unknowns = parameters(m) ∪ arguments(m)
#     unkExpr = Expr(:tuple,unknowns...)
#     @gensym logdensity
#     result = @q begin
#         function $logdensity(pars)
#             @unpack $(unkExpr) = pars
#             $code
#         end
#     end

#     flatten(result)
# end

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

import Distributions.Normal
Normal(μ::Sym, σ::Sym) = stats.Normal(:Normal, μ,σ) |> SymPy.density
Normal(μ,σ) = Normal(promote(μ,σ)...)

# import Distributions.logpdf
# logpdf(d::Sym, x::Symbol) = logpdf(d, sym(x))
# logpdf(d::Sym, x::Sym) = sympy.expand(SymPy.density(d).pdf(x) |> log, log=true, deep=false, force=true)


# logpdf(Normal(sym(:μ),sym(:σ)), :x) |> SymPy.cse



# # macro symdist(n, dist)
# #     p = Expr(:tuple,gensym.(Symbol.(:p,1:n)))
# #     @q begin
# #         $dist($p)
# #     end
# # end
# # @macroexpand @symdist(4,Normal)

function symvar(st::Sample)
    st.rhs.args[1] ∈ [:For, :iid] && return IndexedBase(sy.x)
    return sym(st.x)
end

export sourceSymlogpdf
function sourceSymlogpdf()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))

        function proc(_m, st :: Sample)
            x = symvar(st)

            @q begin
                _ℓ += symlogpdf($(st.rhs), $x)
            end
        end
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end

# logpdf(d::For{F,N,T}, x::Array{Symbol, N}) where {F,N,T} = logpdf(d,sym.(x))

export symlogpdf
function symlogpdf(d::For{F,N,T}, x::Sym) where {F,N,T}
    @show d 
    @show x 
    js = sym.(gensym.(Symbol.(:_j,1:N)))
    return d
    @show js
    result = symlogpdf(d.f(js...), x)

    @show result

    for k in N:-1:1
        result = sympy.Sum(result, (js[k], 1, d.θ[k]))
    end
    result
end

symlogpdf(d::Sym, x::Sym) = d.pdf(x)

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



