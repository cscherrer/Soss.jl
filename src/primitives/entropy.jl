
export entropy


import StatsBase

@inline function StatsBase.entropy(m::ConditionalModel, N::Int=DEFAULT_SAMPLE_SIZE)
    return _entropy(getmoduletypencoding(m.model), m.model, argvals(m), Val(N))
end

@gg M function _entropy(_::Type{M}, _m::Model, _args, _n::Val{_N}) where {M <: TypeLevel{Module},_N}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        sourceEntropy()(type2model(_m), _n()) |> loadvals(_args, NamedTuple()))
end

@gg M function _entropy(_::Type{M}, _m::Model, _args::NamedTuple{()}, _n::Val{_N}) where {M <: TypeLevel{Module},_N}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        sourceEntropy()(type2model(_m), _n))
end

sourceEntropy(m::Model, N::Int=DEFAULT_SAMPLE_SIZE) = sourceEntropy()(m, Val(N))

export sourceEntropy
    
function sourceEntropy() 
        
    function(m::Model, ::Val{_N}) where {_N}
        _m = canonical(m)
        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        
        function proc(_m, st::Sample) 
            if isleaf(_m, st.x)
                return quote
                    _H += mean(entropy($(st.rhs)))
                end
            else
                return quote
                    $(st.x) = parts($(st.rhs), $_N)
                    _H += mean(entropy($(st.rhs)))
                end
            end

        end
        
        
        proc(_m, st::Return)  = nothing # :(return $(st.rhs))
        proc(_m, st::LineNumber) = nothing

        vals = map(x -> Expr(:(=), x,x),variables(_m)) 

        wrap(kernel) = @q begin
            _H = 0.0
            $kernel
            return _H
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end

StatsBase.entropy(d::iid) = prod(d.size) * entropy(d.dist)
StatsBase.entropy(d::For) = sum(entropy ∘ d.f, d.θ)
