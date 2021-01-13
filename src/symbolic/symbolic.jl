using MacroTools: @q
using GeneralizedGenerated
using MLStyle

using SymbolicUtils
using SymbolicUtils: Sym, symtype


import SpecialFunctions
using SpecialFunctions: logfactorial

using NestedTuples: schema

# Convert a type into the SymbolicUtils type we'll use to represent it
# for example,
#     julia> Soss.sym(Int)
#     :(Soss.Sym{Int64})
#     
#     julia> Soss.sym(Int, :n)
#     :(Soss.Sym{Int64}(:n))
#
sym(T::Type) = :(Soss.Sym{$T})

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
    trace = simulate(cm; trace_assignments=true).trace
    vars = merge(trace, argvals(cm))
    return sourceSymlogdensity(schema(vars))(Model(cm))
end

function symlogdensity(cm::ConditionalModel{A,B,M}) where {A,B,M}
    trace = simulate(cm; trace_assignments=true).trace
    vars = merge(trace, argvals(cm))
    s = _symlogdensity(M, Model(cm), vars)
    s = rewrite(s)

    dict = symdict(cm)
    known = Set([Sym{typeof(v)}(k) for (k,v) in pairs(dict)])
    
    p(x) = (symtype(x) <: Number) && (atoms(x) ⊆ known)

    r = @rule ~x::p => toconst(~x, dict)

    RW.Prewalk(RW.PassThrough(r))(s) |> simplify
end

toconst(s::Number, dict) = s

function toconst(s::Symbolic, dict)
    # First, here's the main body of the code
    f_expr = @q begin $(codegen(s)) end

    # Now prepend the variable assignments we'll need
    for v in atoms(s)
        v = v.name
        vname = QuoteNode(v)
        pushfirst!(f_expr.args, :($v = __dict[$vname]))
    end

    # Make it a function
    f_expr = @q begin function f(__dict) $f_expr end end
        
    # Tidy up the blocks
    f_expr = MacroTools.flatten(f_expr)
        
    # ...and generate!
    f = @RuntimeGeneratedFunction f_expr
    
    f(dict)
end

# Convert a named tuple to a dictionary for symbolic substitution
symdict(nt::NamedTuple) = Dict((k => v for (k,v) in pairs(nt)))
symdict(cm::ConditionalModel) = symdict(merge(cm.argvals, cm.obs))

# For(f, θ::Sym) = For(f, (θ,))

# function For(f::F, θ::NTuple{N,Sym}) where {F, N}
#     For{F,NTuple{N,Sym},Sym,Sym}(f,θ)
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


@gg M function _symlogdensity(_::Type{M}, _m::Model, _vars) where M <: TypeLevel{Module}
    Sym = SymbolicUtils.Sym
    types = schema(_vars)
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceSymlogdensity(types))
end
