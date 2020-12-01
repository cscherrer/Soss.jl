using Setfield

export MarkovChain

"""
    MarkovChain

`MarkovChain(pars, step)` defines a Markov Chain with global parameters `pars` and transition kernel `step`. Here, `pars` is a named tuple, and `step` is a Soss model that takes arguments `(pars, state)` and returns a `next` value containing the new `pars` and `state`.

NOTE: This is experimental, and may change in the near future.

```jldoctest
mstep = @model pars,state begin
    σ = pars.σ
    x0 = state.x
    x ~ Normal(x0, σ)
    next = (pars=pars, state=(x=x,))
end;

m = @model s0 begin
    σ ~ Exponential()
    pars = (σ=σ,)
    chain ~ MarkovChain(pars, mstep(pars=pars, state=s0))
end;

r = rand(m(s0=(x=2,),));

for s in Iterators.take(r.chain,3)
    println(s)
end

# output

(x = -6.596883394256064,)
(x = 0.48200039561318864,)
(x = -2.838556784903994,)
```
"""
struct MarkovChain{P,D}
    pars :: P
    step :: D
end

struct MarkovChainRand{R,P,D}
    rng::R
    mc::MarkovChain{P,D}
end

Base.IteratorSize(::MarkovChainRand) = Base.IsInfinite()

Base.eltype(mc::MarkovChainRand{R,P,D}) where {R,P,D} = typeof(mc.dist.args.state)

export next
function next(mc::MarkovChain{P,D}, state) where {P,D}
    @set mc.step.args.state = state
end

function Distributions.logdensity(mc::MarkovChain{P,D}, x::AbstractVector{X}) where {P,D,X}
    ℓ = 0.0
    for xj in x
        ℓ += logdensity(mc.step,xj)
        @set! mc.step.args.state = xj
    end
    return ℓ
end

function Base.iterate(r::MarkovChainRand{R,P,D}) where {R,P,D}
    state = rand(r.mc.step).next.state
    return (state, state)
end

function Base.iterate(r::MarkovChainRand{R,P,D}, state::NamedTuple) where {R,P,D}
    step = next(r.mc,state).step
    newstate = rand(step).next.state
    return (newstate, newstate)
end

Base.rand(rng::AbstractRNG, mc::MarkovChain) = MarkovChainRand(rng, mc)
Base.rand(mc::MarkovChain) = MarkovChainRand(GLOBAL_RNG, mc)

# EXAMPLE 

# pars = (σ = 1.2,)
# s0 = (x=0.0,)

# mstep = @model pars,state begin
#     σ = pars.σ
#     x0 = state.x
#     x ~ Normal(x0, σ)
#     next = (pars=pars, state=(x=x,))
# end

# m = @model s0 begin
#     σ ~ Exponential()
#     pars = (σ=σ,)
#     x ~ MarkovChain(pars, mstep(pars=pars, state=s0))
# end

# r = rand(m(s0=s0))

# for (n,s) in enumerate(r.x)
#     n > 10 && break
#     println(s)
# end
