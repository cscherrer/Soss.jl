
using TransformVariables, Parameters, Distributions, Statistics, StatsFuns, Optim
using NLSolversBase

function makeLoss(model)

    t = getTransform(model)

    fpre = @eval $(logdensity(model))
    f(par, data) = Base.invokelatest(fpre, par, data)

    loss(x, data; init=t(zeros(dimension(t)))) = -f(transform(t, x), data)

    (loss=loss, t=t)
end

export getMAP
function getMAP(m :: Model, data; kwargs...)
    @unpack loss, t = makeLoss(m)
    d = dimension(t) 
    init = get(Dict(kwargs), :init, t(zeros(d)))

    f(θ) = loss(θ, data)
    
    opt = optimize(f, inverse(t)(init))
    t(Optim.minimizer(opt))
end
