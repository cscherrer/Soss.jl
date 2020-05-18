using Soss

mstep = @model pars,state begin
    # Parameters
    α = pars.α        # Transmission rate
    β = pars.β        # Recovery rate
    γ = pars.γ        # Case fatality rate

    # Starting counts
    s0 = state.s      # Susceptible
    i0 = state.i      # Infected 
    r0 = state.r      # Recovered
    d0 = state.d      # Deceased
    n0 = state.n       # Population size
    
    # Transitions between states
    si ~ Binomial(s0, α * i0 / n)
    ir ~ Binomial(i0, β)
    id ~ Binomial(i0-ir, γ)
    
    # Updated counts
    s = s0 - si 
    i = i0 + si - ir - id
    r = r0 + ir
    d = d0 + id
    n = n0 - id

    next = (pars=pars, state=(s=s,i=i,r=r,d=d, n=n))
end;

m = @model s0 begin
    α ~ Uniform()
    β ~ Uniform()
    γ ~ Uniform()
    pars = (α=α, β=β, γ=γ)
    x ~ MarkovChain(pars, mstep(pars=pars, state=s0))
end

s0 = (i = 1, r = 0, d = 0, n = 331000000, s = 330999999);

r = rand(m(s0=s0));

for (n,s) in enumerate(r.x)
    n>100 && break
    n%7==0 && println(s)
end
