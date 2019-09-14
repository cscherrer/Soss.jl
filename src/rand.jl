using GeneralizedGenerated

export rand

EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

@inline function rand(m::JointDistribution)
    return _rand(m.model, m.args)
end

@generated function rand(m::T) where {T <: Model}
    type2model(T) |> sourceRand()
end

@gg function _rand(_m::Model{A,B}, _args::A) where {A,B}
    type2model(_m) |> sourceRand() |> loadvals(_args, NamedTuple())
end

@gg function _rand(_m::Model{A,B}, _args::NamedTuple{()}) where {A, B}
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