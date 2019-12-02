const DEFAULT_SAMPLE_SIZE = 1000

export sourceParticles

foreach([<=, >=, <, >]) do cmp
    MonteCarloMeasurements.register_primitive(cmp, eval)
end

export particles

particles(v::Vector{<:Real}) = Particles(v)
particles(d; N=DEFAULT_SAMPLE_SIZE) = Particles(N, d)

# particles(n :: NUTS_result) = particles(n.samples)
using IterTools

function particles(v::Vector{Vector{T} }) where {T}
    map(eachindex(v[1])) do j particles([x[j] for x in v]) end
end

function particles(s::Vector{NamedTuple{vs, T}}) where {vs, T}
    nt = NamedTuple()
    for k in keys(s[1])
        nt = merge(nt, [k => particles(getproperty.(s,k))])
    end
    nt
end

export parts


# Just a little helper function for particles
# https://github.com/baggepinnen/MonteCarloMeasurements.jl/issues/22
parts(d; N=DEFAULT_SAMPLE_SIZE) = particles(d; N=N)
parts(x::Normal{P} where {P <: AbstractParticles}; N=DEFAULT_SAMPLE_SIZE) = Particles(length(x.μ), Normal()) * x.σ + x.μ
parts(x::Sampleable{F,S}; N=DEFAULT_SAMPLE_SIZE) where {F,S} = Particles(N,x)
parts(x::Integer; N=DEFAULT_SAMPLE_SIZE) = parts(float(x))
parts(x::Real; N=DEFAULT_SAMPLE_SIZE) = parts(repeat([x],N))
parts(x::AbstractArray; N=DEFAULT_SAMPLE_SIZE) = Particles(x)
parts(p::Particles; N=DEFAULT_SAMPLE_SIZE) = p
parts(d::For; N=DEFAULT_SAMPLE_SIZE) = parts.(d.f.(d.θ...))



parts(d::iid; N=1000) = map(1:d.size) do j parts(d.dist) end
# size
# dist 

# MonteCarloMeasurements.Particles(n::Int, d::For) = 
# -(a::Particles{Float64,1000}, b::Array{Float64,1}) = [a-bj for bj in b]

# Base.promote(a::Particles{T,N}, b)  where {T,N} = (a,parts(b))
# Base.promote(a, b::Particles{T,N})  where {T,N} = (parts(a),b)

# promote_rule(::Type{A}, ::Type{B}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N} where {N}
# promote_rule(::Type{B}, ::Type{A}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N} where {N}


@inline function particles(m::JointDistribution)
    return _particles(getmoduletypencoding(m.model), m.model, m.args)
end

@gg M function _particles(_::Type{M}, _m::Model, _args) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceParticles() |> loadvals(_args, NamedTuple()))
end

@gg M function _particles(_::Type{M}, _m::Model, _args::NamedTuple{()}) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceParticles())
end

export sourceParticles
function sourceParticles() 
    function(m::Model)
        
        _m = canonical(m)
        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        proc(_m, st::Sample)  = :($(st.x) = parts($(st.rhs)))
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