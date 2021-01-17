using MacroTools: @q
using GeneralizedGenerated
using MLStyle

using SymbolicUtils
using SymbolicUtils: Sym, Symbolic, symtype


using MappedArrays
import SpecialFunctions
using SpecialFunctions: logfactorial

using NestedTuples: schema
import NestedTuples

export schema

export symlogdensity

symlogdensity(d,x::Symbolic) = logdensity(d,x)

function symlogdensity(d::ProductMeasure{<:AbstractMappedArray}, x::Symbolic{A}) where {A <: AbstractArray}
    dims = size(d.data)

    iters = Sym{Int}.(gensym.(Symbol.(:i, 1:length(dims))))

    # from the type, d wraps a mapped array
    marr = d.data

    T = eltype(marr.data)
    result = symlogdensity(marr.f(term(getindex, marr.data, iters...; type=T)), x[iters...])

    for i in 1:length(dims)
        result = Sum(result, iters[i], 1, dims[i])
    end
    
    return result
end

function NestedTuples.schema(cm::ConditionalModel) 
    trace = simulate(cm; trace_assignments=true).trace
    types = schema(merge(trace, argvals(cm)))
    return types
end

function symlogdensity(cm::ConditionalModel{A,B,M}) where {A,B,M}
    types = schema(cm)
    symlogdensity(cm.model, types, symdict(cm))
end

function symlogdensity(m::Model{A,B,M}, types, dict=Dict()) where {A,B,M}
    s = _symlogdensity(M, m, to_type(types))
    s = rewrite(s)
    return SymbolicCodegen.foldconstants(s, dict)
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


# Convert a type into the SymbolicUtils type we'll use to represent it
# for example,
#     julia> Soss.sym(Int)
#     :(Soss.Sym{Int64})
#     
#     julia> Soss.sym(Int, :n)
#     :(Soss.Sym{Int64}(:n))
#


function sourceSymlogdensity(cm::ConditionalModel{A,B,M}) where {A,B,M}
    types = schema(cm)
    return sourceSymlogdensity(types)(Model(cm))
end

# Convert a type into the SymbolicUtils type we'll use to represent it
# for example,
#     julia> SymbolicCodegen.sym(Int)
#     :(SymbolicCodegen.Sym{Int64})
#     
#     julia> SymbolicCodegen.sym(Int, :n)
#     :(SymbolicCodegen.Sym{Int64}(:n))
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
                _ℓ += symlogdensity($(st.rhs), $x)
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


@gg M function _symlogdensity(_::Type{M}, _m::Model, ::Type{T}) where {T, M <: TypeLevel{Module}}
    types = GeneralizedGenerated.from_type(T)
    Sym = SymbolicUtils.Sym
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceSymlogdensity(types))
end
