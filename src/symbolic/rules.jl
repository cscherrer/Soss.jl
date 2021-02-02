using SymbolicUtils
using SymbolicUtils: Sym, Term, FnType, Symbolic
using SymbolicCodegen: Sum
using CanonicalTraits

# get it?
function gensum(t,i,a,b)
    new_i = Sym{Int}(gensym(:i))
    new_t = substitute(t, Dict(i => new_i))
    return Sum(new_t, new_i, a, b)
end


# type-level stuff for GeneralizedGenerated
@implement NGG.Typeable{Sym{T}} where {T} begin
    function to_type(@nospecialize(s))
        let args = Any[s.name] |> NGG.to_typelist
            NGG.TApp{Sym{T}, Sym{T}, args}
        end
    end
end


using SymbolicUtils.Rewriters
const RW = Rewriters

POSTRULES = [
    @rule getindex(UnitRange(~a,~b), ~i) => ~i - ~a + 1
    @rule (+(~~x))^2 => sum(a*b for a in (~~x) for b in (~~x))
]

PRERULES = [
    @acrule (~a + ~b)*(~c) => (~a) * (~c) + (~b) * (~c)
    @rule Sum(+(~~x), ~i, ~a, ~b) => sum([gensum(t, ~i, ~a, ~b) for t in (~~x)])
    @rule Sum(*(~~x), ~i, ~a, ~b) => SymbolicCodegen.tryfactor(~~x, ~i, ~a, ~b) # ifelse(!_contains(~x,~i) || !_contains(~y,~i), Sum(~x, ~i, ~a, ~b) * Sum(~y, ~i, ~a, ~b), nothing)
    @rule Sum(~x, ~i, ~a, ~b) => ifelse(~i ∈ atoms(~x), nothing, ((~b) - (~a) + 1) * (~x))
]

export rewrite

function rewrite(s)
    # TODO: Put this back once this issue is fixed:
    # https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/175

    s = symify(s) #; polynorm=true)
    s = RW.Postwalk(RW.Fixpoint(RW.Chain(POSTRULES)))(s)
    s = RW.Prewalk(RW.Fixpoint(RW.Chain(PRERULES)))(s)
    s = simplify(s)
end
