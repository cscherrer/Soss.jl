# using Soss
# using TransformVariables, Parameters, Flux, Distributions, Statistics, StatsFuns

# function fluxify(model)
#     t = getTransform(model)
#     z = randn(t.dimension) |> Flux.param

#     fpre = @eval $(logdensity(model))
#     f(par, data) = Base.invokelatest(fpre, par, data)

#     loss(data) = -f(transform(t, z), data)

#     ps = Flux.params(z)

#     (loss=loss, ps=ps, t=t)
# end


# @unpack loss, ps, t = fluxify(normalModel)


# using DataFrames

# df = DataFrame(x=randn(1000))
# data = Iterators.repeated((df,),100);


# history = []
# function evalcb(; df=train) 
#     old = 1e100
#     function cb()
#         train_loss = loss(df) |> Tracker.data
#         @show train_loss
#         # old - train_loss > 1e-10 && Flux.stop()
#         append!(history, train_loss)
#         old = train_loss
#     end

#     cb
# end

# function makecb(; df=df)
#     history = DataFrame(; (ps.order[1].data |> t)...)
#     function cb()
#         push!(history, ps.order[1].data |> t)
#     end
# end 

# cb = makecb()

# using Flux: @epochs
# @epochs 10 Flux.train!(loss, ps, data, ADAM(), cb= Flux.throttle(cb, 0.5))

# @show cb.history

# @show ps.order[1].data |> t

# zSize = 100

# # encode = Chain(
# #     x -> reshape(x, (1, 28, 28. :)
# #   , Conv((4,4), elu, stride=2)
# # )

# # decode = Chain(
# #     Dense(zSize, elu)
# #   , Dense()
# #   , x -> 
# #   , Conv()
# #   , Dropout()
# #   , Conv()
# #   , elu
# # # )

# # vae = @model decode x
# #     xSize = size(x)
# #     n = prod(xSize)
# #     z ~ Normal(0,1) |> iid(n)
# #     ε = x - encode(z)
# #     ε ~ Normal(0,1)
# # end

# function loss()
