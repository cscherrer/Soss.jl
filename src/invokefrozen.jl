
# From Chris Rackauckas: https://github.com/JuliaLang/julia/pull/32737
@inline @generated function _invokefrozen(f, ::Type{rt}, args...) where rt
    tupargs = Expr(:tuple,(a==Nothing ? Int : a for a in args)...)
    quote
        _f = $(Expr(:cfunction, Base.CFunction, :f, rt, :((Core.svec)($((a==Nothing ? Int : a for a in args)...))), :(:ccall)))
        return ccall(_f.ptr,rt,$tupargs,$((:(getindex(args,$i) === nothing ? 0 : getindex(args,$i)) for i in 1:length(args))...))
    end
end

# @cscherrer's modification of `invokelatest` does better on kwargs
export invokefrozen
@inline function invokefrozen(f, rt, args...; kwargs...)
    g(kwargs, args...) = f(args...; kwargs...)
    kwargs = (;kwargs...)
    _invokefrozen(g, rt, (;kwargs...), args...)
end

@inline function invokefrozen(f, rt, args...)
    _invokefrozen(f, rt, args...)
end




# using BenchmarkTools
# f(;kwargs...) = kwargs[:a] + kwargs[:b]

# @btime invokefrozen(f, Int; a=3,b=4)  # 3.466 ns (0 allocations: 0 bytes)
# @btime f(;a=3,b=4)                    # 1.152 ns (0 allocations: 0 bytes)
