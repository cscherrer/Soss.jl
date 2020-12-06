const DEFAULT_SAMPLE_SIZE = 1000

export sourceParticles

foreach([<=, >=, <, >]) do cmp
    MonteCarloMeasurements.register_primitive(cmp, eval)
end

export particles

particles(v::Vector{<:Real}) = Particles(v)
particles(d, N::Int=DEFAULT_SAMPLE_SIZE) = Particles(N, d)

# particles(n :: NUTS_result) = particles(n.samples)
using IterTools

function particles(v::Vector{Vector{T} }) where {T}
    map(eachindex(v[1])) do j particles([x[j] for x in v]) end
end

function particles(v::Vector{Array{T,N} }) where {T,N}
    map(CartesianIndices(v[1])) do j particles([x[j] for x in v]) end
end


function particles(s::Vector{NamedTuple{vs, T}}) where {vs, T}
    nt = NamedTuple()
    for k in keys(s[1])
        nt = merge(nt, [k => particles(getproperty.(s,k))])
    end
    nt
end

export parts

using MappedArrays, FillArrays

# Just a little helper function for particles
# https://github.com/baggepinnen/MonteCarloMeasurements.jl/issues/22
parts(d, N::Int=DEFAULT_SAMPLE_SIZE) = particles(d, N)
parts(x::Normal{P} where {P <: AbstractParticles}, N::Int=DEFAULT_SAMPLE_SIZE) = Particles(length(x.μ), Normal()) * x.σ + x.μ
parts(x::Sampleable{F,S}, N::Int=DEFAULT_SAMPLE_SIZE) where {F,S} = Particles(N,x)
parts(x::Integer, N::Int=DEFAULT_SAMPLE_SIZE) = parts(float(x))
parts(x::Real, N::Int=DEFAULT_SAMPLE_SIZE) = parts(repeat([x],N))
parts(x::AbstractArray, N::Int=DEFAULT_SAMPLE_SIZE) = Particles(x)
parts(p::Particles, N::Int=DEFAULT_SAMPLE_SIZE) = p

function parts(x::Bernoulli{P} where {P <: AbstractParticles}, N::Int=DEFAULT_SAMPLE_SIZE) 
    k = length(x)
    us = Particles(k, Uniform()).particles
    ps = x.p.particles

    return Particles(collect(us .< ps))
end

# function Base.:<(x::AbstractParticles, y::Particles{T,N}) where {T, N}
#     return Particles(x.particles .< y.particles)
# end

# function parts(d::For, N::Int=DEFAULT_SAMPLE_SIZE)
#     ci = CartesianIndices(d.θ)
#     result = similar(Array{Any}, axes(ci))
#     for j in ci
#         result[j] = parts(d.f(Tuple(j)...), N)
#     end
# end

parts(d::For, N::Int=DEFAULT_SAMPLE_SIZE) = parts.((d.f(Tuple(cind)...) for cind in CartesianIndices(d.θ)), N)

parts(d::iid, N::Int=DEFAULT_SAMPLE_SIZE) = parts.(fill(d.dist, d.size))
# size
# dist 

# MonteCarloMeasurements.Particles(n::Int, d::For) = 
# -(a::Particles{Float64,1000}, b::Array{Float64,1}) = [a-bj for bj in b]

# Base.promote(a::Particles{T,N}, b)  where {T,N} = (a,parts(b))
# Base.promote(a, b::Particles{T,N})  where {T,N} = (parts(a),b)

# promote_rule(::Type{A}, ::Type{B}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N} where {N}
# promote_rule(::Type{B}, ::Type{A}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N} where {N}


@inline function particles(m::ConditionalModel, N::Int=DEFAULT_SAMPLE_SIZE)
    return _particles(getmoduletypencoding(m.model), m.model, m.args, Val(N))
end

@gg M function _particles(_::Type{M}, _m::Model, _args, _n::Val{_N}) where {M <: TypeLevel{Module},_N}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        sourceParticles()(type2model(_m), _n) |> loadvals(_args, NamedTuple()))
end

@gg M function _particles(_::Type{M}, _m::Model, _args::NamedTuple{()}, _n::Val{_N}) where {M <: TypeLevel{Module},_N}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        sourceParticles()(type2model(_m), _n))
end

sourceParticles(m::Model, N::Int) = sourceParticles()(m, Val(N))

export sourceParticles
function sourceParticles() 
        
    function(m::Model, ::Type{Val{_N}}) where {_N}
        _m = canonical(m)
        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        proc(_m, st::Sample)  = :($(st.x) = parts($(st.rhs), $_N))
        proc(_m, st::Return)  = :(return $(st.rhs))
        proc(_m, st::LineNumber) = nothing

        vals = map(x -> Expr(:(=), x,x),variables(_m)) 

        wrap(kernel) = @q begin
            $kernel
            $(Expr(:tuple, vals...))
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end

function Base.getindex(a::AbstractArray{P}, i::Particles) where P <: AbstractParticles
    return Particles([a[i.particles[n]][n] for n in eachindex(i.particles)])
end

function Base.getindex(a::AbstractArray{P}, i, j::Particles) where P <: AbstractParticles
    return Particles([a[i,j.particles[n]][n] for n in eachindex(j.particles)])
end

function Base.getindex(a::AbstractArray, i, j::Particles) 
    return Particles([a[i,j.particles[n]] for n in eachindex(j.particles)])
end

function Base.getindex(a::AbstractArray{P}, i::Particles, j) where P <: AbstractParticles
    return Particles([a[i.particles[n], j][n] for n in eachindex(i.particles)])
end

function Base.getindex(a::AbstractArray{P}, i::Particles, j::Particles) where P <: AbstractParticles
    return Particles([a[i.particles[n], j.particles[n]][n] for n in eachindex(i.particles)])
end

# function Base.getindex(a::AbstractArray, i::Particles)
#     return Particles([a[ii] for ii in i.particles])
# end

# function Base.getindex(a::AbstractArray, i::Particles, j::Particles)
#     return Particles([a[ii,jj] for (ii,jj) in zip(i.particles, j.particles)])
# end



# function Base.getindex(a::AbstractArray, i::Particles, j)
#     return Particles([a[ii,j] for ii in i.particles])
# end


# Base.to_indices(A, ::Particles) = i.particles
