
using TransformVariables, Parameters, Statistics, StatsFuns, Optim
using NLSolversBase

function makeLoss(model)

    t = getTransform(model)

    fpre = @eval $(logdensity(model))
    f(par, data) = Base.invokelatest(fpre, par, data)

    loss(x, data) = -f(t(x), data)

    (loss=loss, t=t)
end

export getMAP
function getMAP(m :: DAGModel ;kwargs...)
    @unpack loss, t = makeLoss(m)
    d = dimension(t) 

    kwargs = Dict(kwargs)
    # @show kwargs
    data = get(kwargs, :data, NamedTuple{}())
    init = get(kwargs, :init, t(zeros(d)))

    f(x) = loss(x, data)
    
    opt = optimize(f, inverse(t)(init),method=LBFGS())
    t(Optim.minimizer(opt))
end
