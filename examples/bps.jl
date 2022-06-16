using Soss
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

model = @model (N, C, c) begin
    α ~ Soss.Normal(0,1)
    cc ~ Soss.Normal(0,1) |> iid(C)
    y ~ For(1:N) do i
        v = α + cc[c[i]]
        Soss.Bernoulli(logistic(v))
    end
    return y
end

N = 20000
C = 100
Random.seed!(1)
data = (;c=rand(1:C, N), y=rand(Bool, N))
condmodel = model(;N,C,c=data.c) | (;y=data.y);


function make_grads(my_model, y)        
    post = my_model | (;y)
    as_post = as(post)
    obj(θ) = -logdensityof(post, transform(as_post, θ))
    ℓ(θ) = -obj(θ)
    @inline function dneglogp(t, x, v) # two directional derivatives
        f(t) = obj(x + t*v)
        u = ForwardDiff.derivative(f, Dual{:hSrkahPmmC}(0.0, 1.0))
        u.value, u.partials[]
    end
    
    #gconfig = ForwardDiff.GradientConfig(obj, rand(d), ForwardDiff.Chunk{25}())
    function ∇neglogp!(y, t, x)
        #ForwardDiff.gradient!(y, obj, x, gconfig)
        ForwardDiff.gradient!(y, obj, x)
        return
    end
    post, ℓ, dneglogp, ∇neglogp!
end

post, ℓ, dneglogp, ∇neglogp! = make_grads(model(;N,C,c=data.c), data.y)  
# Try things out


d = C+1 # number of parameters 
dneglogp(2.4, randn(d), randn(d));
#∇neglogp!(randn(d), 2.1, randn(d));

t0 = 0.0;
n = 2000
c = 1.0 # initial guess for the bound

init_scale=0.1;
@time pf_result = pathfinder(ℓ; dim=d, init_scale);
x0 = pf_result.fit_distribution.μ
M = pf_result.fit_distribution.Σ
v0 = PDMats.unwhiten(M, normalize!(randn(length(x0))));
MAP = pf_result.optim_solution; # MAP, could be useful for control variates

∇MAP = zeros(d)
∇neglogp!(∇MAP, 0.0, MAP)


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
collect_sampler(as(post), sampler, 10; progress=false);

elapsed_time = @elapsed @time begin
    global bps_samples, info 
    bps_samples, info = collect_sampler(as(post), sampler, n; progress=true)
end

 
using MCMCChains
bps_chain = MCMCChains.Chains([bps_samples.α bps_samples.cc.data'])
bps_chain = setinfo(bps_chain, (;start_time=0.0, stop_time=elapsed_time));
ess_bps = MCMCChains.ess_rhat(bps_chain).nt.ess_per_sec;

μ̂1 = round.(mean(bps_chain).nt[:mean], sigdigits=4)
println("μ̂ (BPS) = ", μ̂1)

@show info.bound
@show round(info.acc/info.total, sigdigits=2)

bps_chain