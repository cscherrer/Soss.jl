using GeneralizedGenerated

export rand
EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

rand(d::JointDistribution, N::Int) = [rand(d) for n in 1:N]

@inline function rand(m::JointDistribution)
    return _rand(getmoduletypencoding(m.model), m.model, m.args)
end

@inline function rand(m::Model)
    return _rand(getmoduletypencoding(m), m, NamedTuple())
end

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

export sourceRand
function sourceRand() 
    function(m::Model)
        
        _m = canonical(m)
        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        proc(_m, st::Sample)  = :($(st.x) = rand($(st.rhs)))
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