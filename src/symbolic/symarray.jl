using SymbolicUtils
using SymbolicUtils: Sym, Term, FnType, Symbolic
using CanonicalTraits
struct SymArray{T,N,I} <: Symbolic{AbstractArray{T,N}}
    f::Sym{FnType{NTuple{N, I},T}}
    dims::NTuple{N, I}

    function SymArray{T}(name::Symbol, dims::NTuple{N, I}) where {T,N,I}
        f = Sym{FnType{NTuple{N, I},T}}(name)
        new{T,N,I}(f,dims)
    end
end

@implement NGG.Typeable{Sym{T}} where {T} begin
    function to_type(@nospecialize(s))
        let args = Any[s.name] |> NGG.to_typelist
            NGG.TApp{Sym{T}, Sym{T}, args}
        end
    end
end

@implement NGG.Typeable{SymArray{T,N,I}} where {T,N,I} begin
    function to_type(@nospecialize(sa))
        let args = Any[sa.f.name, sa.dims] |> NGG.to_typelist
            NGG.TApp{SymArray{T,N,I}, SymArray{T}, args}
        end
    end
end

SymArray{T}(name::Symbol, dims...) where {T} = SymArray{T}(name, dims)

function SymArray{T, N}(name::Symbol) where {T,N}
    dims = Tuple((Sym{Int}(s) for s in Symbol.(name, :__, 1:N)))
    SymArray{T}(name, dims...)
end

function Base.show(io::IO, ::MIME"text/plain", sa::SymArray{T,N,I}) where {T,N,I}
    join(io, sa.dims, "×")
    print(io, " ")
    print(io, typeof(sa))
    print(io, "(", QuoteNode(sa.f.name), ", ")
    join(io, sa.dims, ", ")
    print(io, ")")
end

Base.size(a::SymArray) = a.dims

Base.getindex(a::SymArray, inds...) = a.f(inds...)




# #############################

@syms Sum(summand, ix, a, b)

# @syms x i
# Sum(x*2^i, i, 1, 4)


using Soss, MeasureTheory





function MeasureTheory.logdensity(d::For, x::Symbolic{A}) where A <: AbstractArray
    N = length(d.θ)
    # inds = Tuple(@. Sym{Int}(gensym(Symbol(:i_, 1:N))))
    inds = Tuple(@. Sym{Int}(Symbol(:i_, 1:N)))
    dist = d.f(inds...)
    obs = x[inds...]
    result = logdensity(dist, obs)
    for n in 1:N
        result = Sum(result, inds[n], 1, d.θ[n])
    end
    return result
end

# μ = SymArray{Float64}(:μ, 5)
# σ = SymArray{Float64}(:σ, 3)

# # d = For(5,3) do i,j Normal(μ[i],σ[j]) end
# d = For(5) do i Normal(μ[i],1) end
# x = SymArray{Float64}(:x,5)

# logdensity(d, x)







# _contains(j^2,i)

# isin(i*j)(i)


# using Chain: @chain

using SymbolicUtils.Rewriters







function atoms(t::Term)
    if hasproperty(t.f, :name) && t.f.name == :Sum
        return setdiff(atoms(t.arguments[1]), [t.arguments[2]])
    else
        return union(atoms(t.f), union(atoms.(t.arguments)...))
    end
end 
atoms(a::SymArray) = Set{Sym}([a])
atoms(s::Sym) = Set{Sym}([s])

atoms(x) = Set{Sym}()

function tryfactor(sumfactors,i,a,b)
    d = Dict([t => i ∈ atoms(t) for t in sumfactors])
    # Which factors are independent of the index?
    indep = filter(t -> !d[t], sumfactors) 
    isempty(indep) && return nothing

    # Start by factoring out the independent factors
    result = prod((Sum(t, i, a, b) for t in indep))

    # Which factors depend on the index?
    dep = filter(t -> d[t], sumfactors)
    # Maybe none do, so we're already done
    isempty(dep) && return result

    # Otherwise, multiply those to the result
    result *= Sum(prod(dep), i, a, b)

    return result
end

using SymbolicUtils: isnotflat, needs_sorting, is_literal_number
using SymbolicUtils: @ordered_acrule, flatten_term, sort_args
const RW = Rewriters


RULES = [
    @rule(~x::isnotflat(+) => flatten_term(+, ~x))
    @rule(~x::needs_sorting(+) => sort_args(+, ~x))
    @ordered_acrule(~a::is_literal_number + ~b::is_literal_number => ~a + ~b)
    @rule(~x::isnotflat(*) => flatten_term(*, ~x))
    @rule(~x::needs_sorting(*) => sort_args(*, ~x))
    @rule (~a + ~b)^2 => (~a) ^2 + 2 * (~a) * (~b) + (~b)^2
    @acrule (~a + ~b)*(~c) => (~a) * (~c) + (~b) * (~c)
    @rule Sum(+(~~x), ~i, ~a, ~b) => sum([Sum(t, ~i, ~a, ~b) for t in (~~x)])
    @rule Sum(*(~~x), ~i, ~a, ~b) => tryfactor(~~x, ~i, ~a, ~b) # ifelse(!_contains(~x,~i) || !_contains(~y,~i), Sum(~x, ~i, ~a, ~b) * Sum(~y, ~i, ~a, ~b), nothing)
    @rule Sum(~x, ~i, ~a, ~b) => ifelse(_contains(~x,~i), nothing, ((~b) - (~a) + 1) * (~x))
]

export rewrite

rewrite = RW.Fixpoint(RW.Prewalk(RW.Chain(RULES)))

# rewrite(s) = SymbolicUtils.simplify(s; polynorm=true)

# a =  logdensity(d, x) |> simplify

# r(a)



using SymbolicUtils
using SymbolicUtils: Sym, Term
using SymbolicUtils.Rewriters
using DataStructures

newsym() = Sym{Number}(gensym("cse"))

function cse(expr)
    dict = OrderedDict()
    r = @rule ~x::(x -> x isa Term) => haskey(dict, ~x) ? dict[~x] : dict[~x] = gensym()
    final = Postwalk(RW.Chain([r]))(expr)
    [[var=>ex for (ex, var) in pairs(dict)]..., final]
end
