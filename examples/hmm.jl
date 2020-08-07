using Revise
using Soss
using ResumableFunctions


hmmStep = @model (s0, step, noise) begin
    s1 ~ EqualMix(step.(s0))
    y ~ noise(s1.x)
end;

function step(s)
    m = @model s begin
        ν ~ HalfCauchy()
        x ~ StudentT(ν, s,1)
    end
    m(s=s)
end;

function noise(s)
    m = @model s begin
        y ~ Normal(s,1)
    end
    m(s=s)
end;

s0 = rand(Normal(0,10), 100);
particles(s0)

rand(hmmStep(s0=s0, step=step, noise=noise)) |> pairs



dynamicHMC(hmmStep(s0=s0, step=step, noise=noise), (y=(y=1.0,),)) |> particles




step(s) = StudentT(3,s,1);
noise(s) = Normal(s,1);


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