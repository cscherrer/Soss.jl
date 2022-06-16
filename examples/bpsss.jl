using Tilde # Loads Tilde, run the Soss model first.
using ProgressMeter
using LinearAlgebra
using Revise
using ZigZagBoomerang
const ZZB = ZigZagBoomerang
using LinearAlgebra
const ∅ = nothing
using DelimitedFiles
using Random
using ForwardDiff
using ForwardDiff: Dual
using Pathfinder
using Pathfinder.PDMats
using MappedArrays

full_ss_model = @Tilde.model N1, C, c, y begin
    α ~ Tilde.Normal()
    cc ~ Tilde.Normal()^C
    for i in 1:N1
        v = α + cc[c[i]]
        y[i] ~ Bernoulli(logitp = v)
    end
end

ss_model = @Tilde.model N1, C, c, K, seed, y begin
    α ~ Tilde.Normal()
    cc ~ Tilde.Normal()^C
    sampler = Random.SamplerRangeNDL(1:N1)
    rng = ZZB.Rng(seed)
    for _ in 1:K
        i = rand(rng, sampler) # each index expected to be sampled (K/N)*n times in n calls
        v = α + cc[c[i]]
        y[i] ~ Bernoulli(logitp = v) ↑ (N/K) # increase weight by power (N/K) 
    end
end

¦(a,b) = Tilde.:|(a, b) # conflict with soss.

function make_grads(full_ss_model, ss_model, N1, C, c, MAP, ∇MAP, K, y) 
    post = full_ss_model(N1,C,c,y) ¦ (;y)   
    as_post = Tilde.as(post)
    post1(seed) = ss_model(N1,C,c,K,seed,y) ¦ (;y)
    obj(θ, seed) = -Tilde.unsafe_logdensityof(post1(seed), Tilde.transform(as_post, θ)) 

    @inline function dneglogp(t, x, v) # two directional derivatives
        seed = hash(t)
        f(t) = obj(x + t*v, seed) - obj(MAP + t*v, seed)
        u = ForwardDiff.derivative(f, Dual{:hSrkahPmmC}(0.0, 1.0))
        u.value - dot(∇MAP, v), u.partials[]
    end
    y2 = copy(MAP)
    function ∇neglogp!(y, t, x)
        seed = hash(t)
        f(x) = obj(x, seed) 
        ForwardDiff.gradient!(y, f, x)
        ForwardDiff.gradient!(y2, f, MAP)
        y .-= y2 .- ∇MAP
        return
    end
    dneglogp, ∇neglogp!
end

K = 500
d = C + 1 # number of parameters 

dneglogp, ∇neglogp! = make_grads(full_ss_model, ss_model, N, C, data.c, MAP, ∇MAP, K, data.y)  
# Try things out


dneglogp(2.4, randn(d), randn(d));
#∇neglogp!(randn(d), 2.1, randn(d));

t0 = 0.0;
n = 1000
c = 10.0 # initial guess for the bound

if norm(∇MAP) > 1e-4
    @warn "norm(∇MAP) = $(norm(∇MAP))"
end

x0 = pf_result.fit_distribution.μ
#M = pf_result.fit_distribution.Σ
M = PDMats.PDiagMat(diag(pf_result.fit_distribution.Σ));
#M = PDMats.PDiagMat(ones(d)*9*(C/N))
v0 = PDMats.unwhiten(M, normalize!(randn(length(x0))));

# define BouncyParticle sampler (has two relevant parameters) 
Z = BouncyParticle(missing, # graphical structure 
    MAP, # MAP estimate, unused
    1.0, # momentum refreshment rate and sample saving rate 
    0.9, # momentum correlation / only gradually change momentum in refreshment/momentum update
    M, # metric (PDMat compatible object for momentum covariance)
    missing # legacy
); 

sampler = ZZB.NotFactSampler(Z, (dneglogp, ∇neglogp!), ZZB.LocalBound(c), t0 => (x0, v0), ZZB.Rng(ZZB.Seed()), (),
(;  adapt=true, # adapt bound c
    subsample=true, # keep only samples at refreshment times
));


using TupleVectors: chainvec
using Soss.MeasureTheory: transform


function collect_sampler(t, sampler, n; progress=true, progress_stops=20)
    if progress
        prg = Progress(progress_stops, 1)
    else
        prg = missing
    end
    stops = ismissing(prg) ? 0 : max(prg.n - 1, 0) # allow one stop for cleanup
    nstop = n/stops

    x1 = transform(t, sampler.u0[2][1])
    tv = chainvec(x1, n)
    ϕ = iterate(sampler)
    j = 1
    local state
    while ϕ !== nothing && j < n
        j += 1
        val, state = ϕ
        tv[j] = transform(t, val[2])
        ϕ = iterate(sampler, state)
        if j > nstop
            nstop += n/stops
            next!(prg) 
        end 
    end
    ismissing(prg) || ProgressMeter.finish!(prg)
    tv, (;uT=state[1], acc=state[3][1], total=state[3][2], bound=state[4].c)
end
#collect_sampler(as(post), sampler, 10; progress=false);

elapsed_time = @elapsed @time begin
    global bps_samples, info2
    bps_samples2, info2 = collect_sampler(as(post), sampler, n; progress=true, progress_stops=500)
end
 
using MCMCChains
bps_chain2 = MCMCChains.Chains([bps_samples2.α bps_samples2.cc.data'])
bps_chain2 = setinfo(bps_chain2, (;start_time=0.0, stop_time=elapsed_time));
ess_bps2 = MCMCChains.ess_rhat(bps_chain2).nt.ess_per_sec;

μ̂2 = round.(mean(bps_chain2).nt[:mean], sigdigits=4)
ŝ2 = round.(vec(std([bps_samples2.α bps_samples2.cc.data'],dims=2)), sigdigits=4)
println("μ̂ (BPS-SS) = ", μ̂2)

@show info2.bound
@show round(info2.acc/info2.total, sigdigits=2)

bps_chain2