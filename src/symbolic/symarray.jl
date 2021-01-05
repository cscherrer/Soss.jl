using SymbolicUtils
using SymbolicUtils: Sym, Term, FnType, Symbolic
using CanonicalTraits

const MaybeSym{T} = Union{T, Symbolic{T}}

function MeasureTheory.logdensity(d::iid,x::Sym{A}) where {A <: AbstractArray}
    dims = d.size
    N = length(dims)

    inds = Tuple(Sym{Int}.(gensym.(Symbol.(:i,1:N))))

    s = logdensity(d.dist, x[inds...])

    for (i,n) in zip(inds, dims)
        s = Sum(s, i, 1, n)
    end

    return s
end





@implement NGG.Typeable{Sym{T}} where {T} begin
    function to_type(@nospecialize(s))
        let args = Any[s.name] |> NGG.to_typelist
            NGG.TApp{Sym{T}, Sym{T}, args}
        end
    end
end



# #############################

struct Summation{F,T}
    f::F
    x::T 
end



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


Base.getindex(a::Sym{A}, inds...) where {T, A <: AbstractArray{T}} = term(getindex, [a, inds...]; type=T)





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


const RW = Rewriters


RULES = [
    @acrule (~a + ~b)*(~c) => (~a) * (~c) + (~b) * (~c)
    @rule Sum(+(~~x), ~i, ~a, ~b) => sum([Sum(t, Sym{Int}(gensym(:i)), ~a, ~b) for t in (~~x)])
    @rule Sum(*(~~x), ~i, ~a, ~b) => tryfactor(~~x, ~i, ~a, ~b) # ifelse(!_contains(~x,~i) || !_contains(~y,~i), Sum(~x, ~i, ~a, ~b) * Sum(~y, ~i, ~a, ~b), nothing)
    @rule Sum(~x, ~i, ~a, ~b) => ifelse(~i ∈ atoms(~x), nothing, ((~b) - (~a) + 1) * (~x))
]

export rewrite

function rewrite(s)
    simplify(s; polynorm=true) |> RW.Fixpoint(RW.Prewalk(RW.Chain(RULES))) |> simplify
end

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
