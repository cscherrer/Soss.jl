using Revise
using Soss
using ResumableFunctions


hmmStep = @model (s0, step, noise) begin
    s1 ~ step(s0)
    x1 ~ noise(s1)
end;

hmmStepM = @model (s0, step, noise) begin
    s1 ~ EqualMix(step.(s0.particles))
    x ~ noise(s1)
end;



s0 = rand(Normal(0,1), 100)

function step(s)
    m = @model s begin
        x ~ Normal(s,1)
    end

    m(s=s)
end

function noise(s)
    m = @model s begin
        x ~ Normal(s,1)
    end

    m(s=s)
end

step(s) = Normal(s,1)
noise(s) = Normal(s,1)

dynamicHMC(hmmStepM(s0=s0, step=step, noise=noise), (x=1.0,)) |> particles

struct Chain
    init
    step
end

@resumable function Base.rand(c::Chain)
    x = rand(c.init)
    @yield x
    while true
        x = rand(c.step(x))
        @yield x
    end
end

# function Distributions.logpdf(c::Chain, xs)

c = Chain(s0, step)

for(n,x) in enumerate(rand(c))
    n > 10 && break
    println(x)
end

m = @model ch begin
    c ~ ch(Normal(), x -> Normal(x,1))
end