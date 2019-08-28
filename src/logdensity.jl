
export logdensity

@generated function logdensity(_m::Model{A,B,D}, _args::A, _data::D, _pars) where {A,B,D} 
    type2model(_m) |> sourceLogdensity |> loadvals(_args, _data, _pars)
end


export sourceLogdensity
function sourceLogdensity(_m::Model)
    proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
    proc(_m, st :: Sample)     = :(_ℓ += logpdf($(st.rhs), $(st.x)))
    proc(_m, st :: Observe)    = :(_ℓ += logpdf($(st.rhs), $(st.x)))
    proc(_m, st :: Return)     = nothing
    proc(_m, st :: LineNumber) = nothing

    wrap(kernel) = @q begin
        _ℓ = 0.0
        $kernel
        return _ℓ
    end
    
    buildSource(_m, proc, wrap) |> flatten
end

