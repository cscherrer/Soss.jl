using Revise
using Soss
using ResumableFunctions

hmmStepM = @model (ss0, step, noise) begin
    s1 ~ EqualMix(map(step, ss0))
    x ~ noise(s1)
end;


hmmStep = @model (s0, step, noise) begin
    s1 ~ step(s0)
    x1 ~ noise(s1)
end;

s0 = Normal(0,1)
step(s) = Normal(s,1)
noise(s) = Normal(s,1)

dynamicHMC(hmmStep(ss0=rand(s0,10), step=step, noise=noise), (x=1.0,)) |> particles

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