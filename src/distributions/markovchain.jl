using Setfield

export MarkovChain

"""
    MarkovChain

`MarkovChain(pars, step)` defines a Markov Chain with global parameters `pars` and transition kernel `step`. Here, `pars` is a named tuple, and `step` is a Soss model that takes arguments `(pars, state)` and returns a `next` value containing the new `pars` and `state`.


mstep = @model pars,state begin
    σ = pars.σ
    x0 = state.x
    x ~ Normal(x0, σ)
    next = (pars=pars, state=(x=x,))
end

m = @model s0 begin
    σ ~ Exponential()
    pars = (σ=σ,)
    x ~ MarkovChain(pars, mstep(pars=pars, state=s0))
end
"""
struct MarkovChain{P,D}
    pars :: P
    step :: D
end

struct MarkovChainRand{P,D}
    mc::MarkovChain{P,D}
end

function Distributions.logpdf(chain::MarkovChain{P,D}, x::AbstractVector{X}) where {P,D,X}
    @inbounds x1 = (pars=chain.pars,state=x[1])
    length(x) == 1 && return logpdf(chain.step, x1.state)
    chain_next = MarkovChain(chain.pars, chain.step.model(x1))
    v = @inbounds @view x[2:end]
    result = logpdf(chain.step, x1.state)
    chain = chain_next
    x = v
    return result + logpdf(chain,x)
end

export next


function next(mc::MarkovChain{P,D}, state) where {P,D}
    @set mc.step.args.state = state
end

function Base.iterate(r::MarkovChainRand{P,D}) where {P,D}
    state = rand(r.mc.step).next.state
    return (state, state)
end

function Base.iterate(r::MarkovChainRand{P,D}, state::NamedTuple) where {P,D}
    step = next(r.mc,state).step
    newstate = rand(step).next.state
    return (newstate, newstate)
end

Base.rand(mc::MarkovChain) = MarkovChainRand(mc)


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
