
export weightedSample

function weightedSample(m::ConditionalModel, _data) 
    return _weightedSample(getmoduletypencoding(m.model), m.model, m.args, _data)    
end

export sourceWeightedSample

sourceWeightedSample(m::Model, data=NamedTuple()) = sourceWeightedSample(data)(m)

function sourceWeightedSample(_data)
    function(_m::Model)

        _datakeys = getntkeys(_data)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        function proc(_m, st :: Sample)
            st.x ∈ _datakeys && return :(_ℓ += logdensity_def($(st.rhs), $(st.x)))
            return :($(st.x) = rand($(st.rhs)))
        end

        vals = map(x -> Expr(:(=), x,x),variables(_m)) 

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            
            return (_ℓ, $(Expr(:tuple, vals...)))
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

@gg function _weightedSample(M::Type{<:TypeLevel}, _m::Model, _args, _data)
    body = type2model(_m) |> sourceWeightedSample(_data) |> loadvals(_args, _data)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end
