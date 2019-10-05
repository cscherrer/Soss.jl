hmmStep = @model (ss0, step, noise) begin
    s1 ~ EqualMix(map(step, ss0))
    x ~ noise(s1)
end;

s = randn(10)
step = s -> Normal(s,1)
noise = s -> Normal(s,1)

dynamicHMC(hmmStep(ss0=s, step=step, noise=noise), (x=1.0,)) |> particles

struct Chain
    init
    step
end

function Distributions.logpdf(c::Chain, xs)
    