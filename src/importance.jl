using Distributions
using MonteCarloMeasurements

"""
    importanceSample(p(p_args), q(q_args), observed_data)

Sample from `q`, and weight the result to behave as if the sample were taken from `p`. For example,

```
julia> p = @model begin
    x ~ Normal()
    y ~ Normal(x,1) |> iid(5)
end;

julia> q = @model μ,σ begin
    x ~ Normal(μ,σ)
end;

julia> y = rand(p()).y;

julia> importanceSample(p(),q(μ=0.0, σ=0.5), (y=y,))
Weighted(-7.13971.4
,(x = -0.12280566635062592,)
````
"""
function importanceSample end

export importanceSample
@inline function importanceSample(p::ConditionalModel, q::ConditionalModel, _data)
    return _importanceSample(getmoduletypencoding(p.model), p.model, p.args, q.model, q.args, _data)
end

@gg M function _importanceSample(_::Type{M}, p::Model, _pargs, q::Model, _qargs, _data) where M <: TypeLevel{Module}
    p = type2model(p)
    q = type2model(q)
        
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        sourceImportanceSample(_data)(p,q) |> loadvals(_qargs, _data) |> loadvals(_pargs, NamedTuple()) |> merge_pqargs)


end

sourceImportanceSample(p::Model,q::Model,_data) = sourceImportanceSample(_data)(p::Model,q::Model)

export sourceImportanceSample
function sourceImportanceSample(_data)
    function(p::Model,q::Model)
        p = canonical(p)
        q = canonical(q)
        m = merge(p,q)

        _datakeys = getntkeys(_data)

        function proc(m, st::Sample) 
            st.x ∈ _datakeys && return :(_ℓ += logpdf($(st.rhs), $(st.x)))

            if hasproperty(p.dists, st.x)
                pdist = getproperty(p.dists, st.x)
                qdist = getproperty(q.dists, st.x)
                @gensym ℓx
                result = @q begin
                    $ℓx = importanceSample($pdist, $qdist, _data)
                    _ℓ += $ℓx.ℓ
                    $(st.x) = $ℓx.val
                end
                return flatten(result)
            else return :($(st.x) = rand($(st.rhs)))
            end
            return flatten(result)
        end
        proc(m, st::Assign)     = :($(st.x) = $(st.rhs))
        proc(m, st::Return)  = :(return $(st.rhs))
        proc(m, st::LineNumber) = nothing

        body = buildSource(m, proc) |> flatten

        kwargs = arguments(p) ∪ arguments(q)
        kwargsExpr = Expr(:tuple,kwargs...)

        stochExpr = begin
            vals = map(sampled(q)) do x Expr(:(=), x,x) end
            Expr(:tuple, vals...)
        end

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $body
            return Weighted(_ℓ, $stochExpr)
        end

        buildSource(m, proc, wrap) |> flatten
    end
end

@inline function importanceSample(p, q, _data)
    x = rand(q)
    ℓ = logpdf(p,x) - logpdf(q,x)
    Weighted(ℓ,x)
end




# export sourceParticleImportance
# function sourceParticleImportance(p,q;ℓ=:ℓ)
#     p = canonical(p)
#     q = canonical(q)
#     @gensym N
#     # This determines how to initialize a Particle for a given expression
#     vars(expr) = (bound(p) ∪ bound(q) ∪ stochastic(p) ∪ stochastic(q)) ∩ variables(expr)

#     procp(p, st::Follows) = :($ℓ += logpdf($(st.rhs), $(st.x)))
#     procp(p, st::Let)     = convert(Expr, st)
#     procp(p, st::Return)  = nothing
#     procp(p, st::LineNumber) = convert(Expr, st)

#     function procq(q, st::Follows)
#         if isempty(vars(st.rhs)) 
#             @q begin
#                 $(st.x) = Particles($N, $(st.rhs))
#                 $ℓ -= logpdf($(st.rhs), $(st.x))
#             end
#         else
#             @q begin
#                 $(st.x) = rand($(st.rhs))
#                 $ℓ -= logpdf($(st.rhs), $(st.x))
#             end
#         end
#     end
#     procq(q, st::Let)     = convert(Expr, st)
#     procq(q, st::Return)  = nothing
#     procq(q, st::LineNumber) = convert(Expr, st)

#     pbody = buildSource(p, procp) |> striplines
#     qbody = buildSource(q, procq) |> striplines

#     kwargs = freeVariables(q) ∪ arguments(p)
#     kwargsExpr = Expr(:tuple,kwargs...)

#     stochExpr = begin 
#         vals = map(stochastic(q)) do x Expr(:(=), x,x) end
#         Expr(:tuple, vals...)
#     end
    
#     @gensym particleImportance
#     result = @q function $particleImportance($N, pars)
#         @unpack $kwargsExpr = pars
#         $ℓ = 0.0 * Particles($N, Uniform())
#         $qbody
#         $pbody
#         return ($ℓ, $stochExpr)
#     end

#     flatten(result)
# end


    
#     @gensym rand
    
#     flatten(@q (
#         function $rand(args...;kwargs...) 
#             @unpack $argsExpr = kwargs
#             # kwargs = Dict(kwargs)
#             $body
#             $stochExpr
#         end
#     ))

# end

function merge_pqargs(src)
    @q begin
        _args = merge(_pargs, _qargs)
        $src
    end |> flatten
end
