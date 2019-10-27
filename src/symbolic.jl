using MacroTools: @q
import PyCall
using MLStyle

import SymPy
using SymPy: Sym, sympy, symbols
import SymPy.sympy

const symfuncs = Dict()

_pow(a,b) = float(a) ^ b

function __init__()
    stats = PyCall.pyimport_conda("sympy.stats", "sympy")
    SymPy.import_from(stats)
    global stats = stats
    
    for dist in [:Normal, :Cauchy, :Laplace, :Beta, :Uniform]
        @eval begin
            Distributions.$dist(μ::Sym, σ::Sym) = stats.$dist(:dist, μ,σ) |> SymPy.density
            Distributions.$dist(μ,σ) = $dist(promote(μ,σ)...)
        end    
    end



    # https://discourse.julialang.org/t/pyobjects-as-keys/26521/2
    merge!(symfuncs, Dict(
        sympy.log => Base.log
      , sympy.Pow => _pow
      , sympy.Abs => Base.abs
      , sympy.Indexed => getindex
    ))

end




export sym
sym(s::Symbol) = SymPy.symbols(s, real=true)
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
    # println("expandSum")
    # @show s
    # println()
    @assert s.func == sympy.Sum
    sfunc = s.args[1].func
    sargs = s.args[1].args
    limits = s.args[2]
    ix = limits.args[1]
    if sfunc == sympy.Add
        return sfunc([maybesum(t, limits) for t in sargs]...)
    elseif sfunc == sympy.Mul
        factors = sargs
        constants = [fac for fac in factors if !(ix in fac)]
        newconst = foldl(*,constants)
        newfacs = foldl(*,setdiff(factors, constants))
        newsum = sympy.Sum(newfacs, limits)
        return newconst * newsum
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
    # println("maybeSum")
    # @show t,limits
    # println()
    (ix, ixlo, ixhi) = limits.args
    ix = limits.args[1]
    ix ∉ t && return t * (ixhi - ixlo + 1)
    # TODO: Force reduction of sums that don't include parameters
    return sympy.Sum(t, limits)
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
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))

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

            for st in map(v -> findStatement(_m,v), toposortvars(_m))
                x = st.x 
                xname = QuoteNode(x)
                rhs = st.rhs 
                xsym = ifelse(rhs.args[1] ∈ [:For, :iid]
                    , :(sympy.IndexedBase($xname))
                    , :(sym($xname))
                )
                push!(q.args, :($x = $xsym))
            end

            q = @q begin
                $q 
                $kernel
                return _ℓ
            end
        end

                

        buildSource(_m, proc, wrap) |> flatten
    end
end

# logpdf(d::For{F,N,T}, x::Array{Symbol, N}) where {F,N,T} = logpdf(d,sym.(x))

export symlogpdf
function symlogpdf(d::For{F,N,X}, x::Sym) where {F,N,X}
    js = sym.(Symbol.(:_j,1:N))
    x = sympy.IndexedBase(x)
    result = symlogpdf(d.f(js...), x[js...]) |> expandSums


    for k in N:-1:1
        result = sympy.Sum(result, (js[k], 1, d.θ[k])) |> expandSums
    end
    result
end

symlogpdf(d::For{F,N,X}, x::Symbol) where {F,N,X} = symlogpdf(d,sym(x))

symlogpdf(d::Normal, x::Sym) = symlogpdf(Normal(sym(d.μ),sym(d.σ)), x)

# @generated function symlogpdf(d,x::Sym)
#     quote
#         args = propertynames(d)

#     end
# end

function symlogpdf(d::Sym, x::Sym) 
    result = d.pdf(x) |> log
    sympy.expand_log(result,force=true)
end


function symlogpdf(m::JointDistribution)
    return _symlogpdf(m.model)    
end

@gg function _symlogpdf(_m::Model)  
    type2model(_m) |> canonical |> sourceSymlogpdf() 
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




