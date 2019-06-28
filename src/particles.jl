@reexport using DataFrames


export sourceParticles


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

function sourceParticles(m::Model)
    m = canonical(m)
    proc(m, st::Let)     = :($(st.x) = $(st.rhs))
    proc(m, st::Follows) = :($(st.x) = parts($(st.rhs)))
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
        function $particles(args...;kwargs...) 
            @unpack $argsExpr = kwargs
            $body
            $stochExpr
        end
    ))

end

export parts

N = 1000
parts(x::Normal{P} where {P <: AbstractParticles}) = Particles(length(x.μ), Normal()) * x.σ + x.μ
parts(x::Sampleable{F,S}) where {F,S} = Particles(N,x)
parts(x::Integer) = parts(float(x))
parts(x::Real) = parts(repeat([x],N))
parts(x::AbstractArray) = Particles(x)
parts(p::Particles) = p 
parts(d::For) = map(d.θs) do θ 
    parts(d.f(θ))
end



parts(d::iid) = map(1:d.size) do j parts(d.dist) end
# size
# dist 

# MonteCarloMeasurements.Particles(n::Int, d::For) = 
# -(a::Particles{Float64,1000}, b::Array{Float64,1}) = [a-bj for bj in b]

# Base.promote(a::Particles{T,N}, b)  where {T,N} = (a,parts(b))
# Base.promote(a, b::Particles{T,N})  where {T,N} = (parts(a),b)

promote_rule(::Type{A}, ::Type{B}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N}
promote_rule(::Type{B}, ::Type{A}) where {A <: Real, B <: AbstractParticles{T,N}} where {T} = AbsractParticles{promote_type(A,T),N}
