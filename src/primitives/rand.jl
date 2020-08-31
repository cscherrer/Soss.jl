using GeneralizedGenerated
using Random: GLOBAL_RNG

export rand
EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

rand(rng::AbstractRNG, d::JointDistribution, N::Int) = [rand(rng, d) for n in 1:N]

rand(d::JointDistribution, N::Int) = rand(GLOBAL_RNG, d, N)

@inline function rand(rng::AbstractRNG, m::JointDistribution)
    return _rand(getmoduletypencoding(m.model), m.model, m.args)(rng)
end

@inline function rand(m::JointDistribution) 
    rand(GLOBAL_RNG, m)
end

@inline function rand(rng::AbstractRNG, m::Model)
    return _rand(getmoduletypencoding(m), m, NamedTuple())(rng)
end

rand(m::Model) = rand(GLOBAL_RNG, m)

@gg M function _rand(_::Type{M}, _m::Model, _args) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceRand() |> loadvals(_args, NamedTuple()))
end

@gg M function _rand(_::Type{M}, _m::Model, _args::NamedTuple{()}) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceRand())
end

sourceRand(m::Model) = sourceRand()(m)
sourceRand(jd::JointDistribution) = sourceRand(jd.model)

export sourceRand
function sourceRand() 
    function(m::Model)
        
        _m = canonical(m)
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

        buildSource(_m, proc, wrap) |> flatten
    end
end
