import StatsBase

# function simulate(rng::AbstractRNG, cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals}
#     m = Model(cm)
#     cm0 = setReturn(m, nothing)(argvals(cm))
#     info = StructArray(simulate(rng, cm0, N))
#     vals = [predict(cm, pars) for pars in info]
#     return StructArray{Noted}((vals, info))
# end

# function simulate(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals} 
#     return simulate(GLOBAL_RNG, cm, N)
# end


# function simulate(rng::AbstractRNG, cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}) where {A,B,M,Argvals}
#     m = Model(cm)
#     cm0 = setReturn(m, nothing)(argvals(cm))
#     info = simulate(rng, cm0)
#     val = predict(cm, info)
#     return Noted(val, info)
# end

# function simulate(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}) where {A,B,M,Argvals}
#     return simulate(GLOBAL_RNG, cm)
# end

using GeneralizedGenerated
using Random: GLOBAL_RNG
using NestedTuples

EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple
export simulate

function simulate(rng::AbstractRNG, d::ConditionalModel, N::Int)
    x = simulate(rng, d)
    T = typeof(x)
    ta = TupleArray{T, 1}(undef, N)
    @inbounds ta[1] = x

    for j in 2:N
        @inbounds ta[j] = simulate(rng, d)
    end

    return ta
end

simulate(d::ConditionalModel, N::Int) = simulate(GLOBAL_RNG, d, N)

@inline function simulate(rng::AbstractRNG, c::ConditionalModel)
    m = Model(c)
    return _simulate(getmoduletypencoding(m), m, argvals(c))(rng)
end

@inline function simulate(m::ConditionalModel) 
    simulate(GLOBAL_RNG, m)
end

@inline function simulate(rng::AbstractRNG, m::Model)
    return _simulate(getmoduletypencoding(m), m, NamedTuple())(rng)
end

simulate(m::Model) = simulate(GLOBAL_RNG, m)

@gg M function _simulate(_::Type{M}, _m::Model, _args) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceSample() |> loadvals(_args, NamedTuple()))
end

@gg M function _simulate(_::Type{M}, _m::Model, _args::NamedTuple{()}) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceSample())
end

sourceSample(m::Model) = sourceSample()(m)
sourceSample(jd::ConditionalModel) = sourceSample(jd.model)

export sourceSample
function sourceSample() 
    function(m::Model)
        _m = canonical(m)
        pars = sort(sampled(_m))
        
        _traceName = Dict((k => Symbol(:_trace_, k) for k in pars))

        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        
        proc(_m, st::Sample)  = @q begin
            $(_traceName[st.x]) = simulate(_rng, $(st.rhs))
            $(st.x) = value($(_traceName[st.x]))
        end

        proc(_m, st::Return)  = :(_value = $(st.rhs))
        proc(_m, st::LineNumber) = nothing

        _traces = map(x -> Expr(:(=), x,_traceName[x]), pars) 

        wrap(kernel) = @q begin
            _rng -> begin
                _value = nothing
                $kernel
                _trace = $(Expr(:tuple, _traces...))
                return (value = _value, trace = _trace)
            end
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

simulate(rng::AbstractRNG, d::Distribution) = rand(rng, d)

simulate(rng::AbstractRNG, d::iid{Int}) = [simulate(rng, d.dist) for j in 1:d.size]

trace(x::NamedTuple) = x.trace
trace(x) = x

using MeasureTheory: AbstractMeasure

simulate(rng::AbstractRNG, μ::AbstractMeasure) = rand(rng, μ)
