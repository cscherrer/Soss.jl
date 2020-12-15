import StatsBase

# function StatsBase.sample(rng::AbstractRNG, cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals}
#     m = Model(cm)
#     cm0 = setReturn(m, nothing)(argvals(cm))
#     info = StructArray(sample(rng, cm0, N))
#     vals = [predict(cm, pars) for pars in info]
#     return StructArray{Noted}((vals, info))
# end

# function StatsBase.sample(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}, N::Int) where {A,B,M,Argvals} 
#     return sample(GLOBAL_RNG, cm, N)
# end


# function StatsBase.sample(rng::AbstractRNG, cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}) where {A,B,M,Argvals}
#     m = Model(cm)
#     cm0 = setReturn(m, nothing)(argvals(cm))
#     info = sample(rng, cm0)
#     val = predict(cm, info)
#     return Noted(val, info)
# end

# function StatsBase.sample(cm::ConditionalModel{A,B,M,Argvals,EmptyNTtype}) where {A,B,M,Argvals}
#     return sample(GLOBAL_RNG, cm)
# end

using GeneralizedGenerated
using Random: GLOBAL_RNG
using NestedTuples

EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple
export sample

function StatsBase.sample(rng::AbstractRNG, d::ConditionalModel, N::Int)
    x = sample(rng, d)
    T = typeof(x)
    ta = TupleArray{T, 1}(undef, N)
    @inbounds ta[1] = x

    for j in 2:N
        @inbounds ta[j] = sample(rng, d)
    end

    return ta
end

StatsBase.sample(d::ConditionalModel, N::Int) = sample(GLOBAL_RNG, d, N)

@inline function StatsBase.sample(rng::AbstractRNG, c::ConditionalModel)
    m = Model(c)
    return _sample(getmoduletypencoding(m), m, argvals(c))(rng)
end

@inline function StatsBase.sample(m::ConditionalModel) 
    sample(GLOBAL_RNG, m)
end

@inline function StatsBase.sample(rng::AbstractRNG, m::Model)
    return _sample(getmoduletypencoding(m), m, NamedTuple())(rng)
end

StatsBase.sample(m::Model) = sample(GLOBAL_RNG, m)

@gg M function _sample(_::Type{M}, _m::Model, _args) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceSample() |> loadvals(_args, NamedTuple()))
end

@gg M function _sample(_::Type{M}, _m::Model, _args::NamedTuple{()}) where M <: TypeLevel{Module}
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
        pars = sort(parameters(_m))
        
        _traceName = Dict((k => Symbol(:_trace_, k) for k in pars))

        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        
        proc(_m, st::Sample)  = @q begin
            $(_traceName[st.x]) = sample(_rng, $(st.rhs))
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

        buildSource(_m, proc, wrap) |> flatten
    end
end

StatsBase.sample(rng::AbstractRNG, d::Distribution) = rand(rng, d)

StatsBase.sample(rng::AbstractRNG, d::iid{Int}) = [sample(rng, d.dist) for j in 1:d.size]

trace(x::NamedTuple) = x.trace
trace(x) = x
