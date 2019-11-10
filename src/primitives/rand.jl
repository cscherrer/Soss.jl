using GeneralizedGenerated

export rand

EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

@inline function rand(m::JointDistribution)
    return _rand(m.model, m.args)
end

@inline function rand(m::Model)
    return _rand(m, NamedTuple())
end

@gg function _rand(_m::Model, _args) 
    type2model(_m) |> sourceRand() |> loadvals(_args, NamedTuple())
end

@gg function _rand(_m::Model, _args::NamedTuple{()})
    type2model(_m) |> sourceRand()
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