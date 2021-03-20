using GeneralizedGenerated
using Random: GLOBAL_RNG
using SampleChains: chainvec

export rand
EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

function Base.rand(rng::AbstractRNG, d::ConditionalModel, N::Int)
    r = chainvec(rand(rng, d), N)
    for j in 2:N
        @inbounds r[j] = rand(rng, d)
    end
    return r
end

Base.rand(d::ConditionalModel, N::Int) = rand(GLOBAL_RNG, d, N)

@inline function Base.rand(rng::AbstractRNG, c::ConditionalModel)
    m = Model(c)
    return _rand(getmoduletypencoding(m), m, argvals(c))(rng)
end

@inline function Base.rand(m::ConditionalModel) 
    rand(GLOBAL_RNG, m)
end

@inline function Base.rand(rng::AbstractRNG, m::Model)
    return _rand(getmoduletypencoding(m), m, NamedTuple())(rng)
end

rand(m::Model) = rand(GLOBAL_RNG, m)



sourceRand(m::Model) = sourceRand()(m)
sourceRand(jd::ConditionalModel) = sourceRand(jd.model)

export sourceRand
function sourceRand() 
    function(_m::Model)
        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        proc(_m, st::Sample)  = :($(st.x) = rand(_rng, $(st.rhs)))
        proc(_m, st::Return)  = :(return $(st.rhs))
        proc(_m, st::LineNumber) = nothing

        vals = map(x -> Expr(:(=), x,x),parameters(_m)) 

        wrap(kernel) = @q begin
            _rng -> begin
                $kernel
                $(Expr(:tuple, vals...))
            end
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

@gg function _rand(M::Type{<:TypeLevel}, _m::Model, _args)
    body = type2model(_m) |> sourceRand() |> loadvals(_args, NamedTuple())
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end

@gg function _rand(M::Type{<:TypeLevel}, _m::Model, _args::NamedTuple{()})
    body = type2model(_m) |> sourceRand()
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end
