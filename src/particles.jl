@reexport using DataFrames


export sourceParticles

foreach([<=, >=, <, >]) do cmp
    MonteCarloMeasurements.register_primitive(cmp, eval)
end

export makeParticles
function makeParticles(m :: Model)
    fpre = @eval $(sourceParticles(m))
    f(;kwargs...) = Base.invokelatest(fpre; kwargs...)
end

export particles
particles(m::Model; kwargs...) = makeParticles(m)(;kwargs...)

function particles(m::Model, n::Int64; kwargs...)
    r = makeParticles(m)
    [r(;kwargs...) for j in 1:n] |> DataFrame

end

particles(d) = Particles(1000, d)

function sourceParticles(m::Model)
    m = canonical(m)
    proc(m, st::Assign)     = :($(st.x) = $(st.rhs))
    proc(m, st::Sample) = :($(st.x) = parts($(st.rhs)))
    proc(m, st::Observe) = :($(st.x) = parts($(st.rhs)))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    body = buildSource(m, proc) |> striplines
    
    argsExpr = Expr(:tuple,freeVariables(m)...)

    stochExpr = begin
        vals = map(variables(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    
    @gensym particles
    
    flatten(@q (
        function $particles(args...) 
            $body
            $stochExpr
        end
    ))

end

# particles(n :: NUTS_result) = particles(n.samples)

function particles(s::Vector{NamedTuple{vs, T}} where {vs, T})
    nt = NamedTuple()
    for v in keys(s[1])
        nt = merge(nt, [v => Particles(getproperty.(s,v))])
    end
    nt
end

export parts


# Just a little helper function for particles
# https://github.com/baggepinnen/MonteCarloMeasurements.jl/issues/22
parts(m::Model; N=1000) = particles(m)
parts(x::Normal{P} where {P <: AbstractParticles}; N=1000) = Particles(length(x.μ), Normal()) * x.σ + x.μ
parts(x::Sampleable{F,S}; N=1000) where {F,S} = Particles(N,x)
parts(x::Integer; N=1000) = parts(float(x))
parts(x::Real; N=1000) = parts(repeat([x],N))
parts(x::AbstractArray; N=1000) = Particles(x)
parts(p::Particles; N=1000) = p 
parts(d::For; N=1000) = map(d.θs) do θ 
    parts(d.f(θ))
end



parts(d::iid; N=1000) = map(1:d.size) do j parts(d.dist) end
# size
# dist 

# MonteCarloMeasurements.Particles(n::Int, d::For) = 
# -(a::Particles{Float64,1000}, b::Array{Float64,1}) = [a-bj for bj in b]

# Base.promote(a::Particles{T,N}, b)  where {T,N} = (a,parts(b))
# Base.promote(a, b::Particles{T,N})  where {T,N} = (parts(a),b)

# promote_rule(::Type{A}, ::Type{B}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N} where {N}
# promote_rule(::Type{B}, ::Type{A}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N} where {N}
