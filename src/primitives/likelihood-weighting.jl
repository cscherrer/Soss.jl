
export weightedSample

function weightedSample(m::JointDistribution, _data) 
    return _weightedSample(getmoduletypencoding(m.model), m.model, m.args, _data)    
end

@gg M function _weightedSample(_::Type{M}, _m::Model, _args, _data) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceWeightedSample(_data) |> loadvals(_args, _data))
end

sourceWeightedSample(m::Model, data=NamedTuple()) = sourceWeightedSample(data)(m)

function sourceWeightedSample(_data)
    function(_m::Model)

        _datakeys = getntkeys(_data)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        function proc(_m, st :: Sample)
            st.x ∈ _datakeys && return :(_ℓ += logpdf($(st.rhs), $(st.x)))
            return :($(st.x) = rand($(st.rhs)))
        end

        vals = map(x -> Expr(:(=), x,x),variables(_m)) 

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            
            return (_ℓ, $(Expr(:tuple, vals...)))
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end
