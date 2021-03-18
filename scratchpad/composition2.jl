using Soss


μdist = @model ν begin
    s ~ Gamma(ν , ν)
    z ~ Normal()
    return sqrt(s)*z
end

σdist = @model begin
    x ~ Normal()
    return abs(x)
end

m = @model begin
    μ ~ μdist(ν=1.0)
    σ ~ σdist()
    x ~ Normal(μ,σ) |> iid(10)
    return x
end

simulate(μdist(ν=1.0))

simulate(σdist())

simulate(m())

rand(m())

x = randn(2)

xform(m() | (x=x, μ = (z = 1.0,)))

dynamicHMC(m() | (x=x, μ = (z = 1.0,)))


_data = (x=x, μ = (z = 1.0,))


# function show(io::IO, t::NamedTuple)
#     n = nfields(t)
#     for i = 1:n
#         # if field types aren't concrete, show full type
#         if typeof(getfield(t, i)) !== fieldtype(typeof(t), i)
#             show(io, typeof(t))
#             print(io, "(")
#             show(io, Tuple(t))
#             print(io, ")")
#             return
#         end
#     end
#     if n == 0
#         print(io, "NamedTuple()")
#     else
#         typeinfo = get(io, :typeinfo, Any)
#         print(io, "(")
#         for i = 1:n
#             print(io, fieldname(typeof(t),i), " = ")
#             show(IOContext(io, :typeinfo =>
#                            t isa typeinfo <: NamedTuple ? fieldtype(typeinfo, i) : Any),
#                  getfield(t, i))
#             if n == 1
#                 print(io, ",")
#             elseif i < n
#                 print(io, ", ")
#             end
#         end
#         print(io, ")")
#     end
# end
