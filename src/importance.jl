using Distributions
using MonteCarloMeasurements

export importanceSample
@inline function importanceSample(p::JointDistribution, q::JointDistribution, _data)
    return _importanceSample(getmodule(p.model), p.model, p.args, q.model, q.args, _data)    
end

@gg M function _importanceSample(M::Module, p::Model, _pargs, q::Model, _qargs, _data)  
    p = type2model(p)
    q = type2model(q)

    sourceImportanceSample()(p,q) |> loadvals(_qargs, _data) |> loadvals(_pargs, NamedTuple())
end

export sourceImportanceSample
function sourceImportanceSample()
    function(p::Model,q::Model)
        p = canonical(p)
        q = canonical(q)
        m = merge(p,q)

        function proc(m, st::Sample) 
            if hasproperty(p.dists, st.x)
                pdist = getproperty(p.dists, st.x)
                qdist = st.rhs
                @gensym ℓx
                result = @q begin
                    $ℓx = importanceSample($pdist, $qdist, _data)
                    _ℓ += $ℓx.ℓ
                    $(st.x) = $ℓx.val
                end
                return flatten(result)
            else return :($(st.x) = $(st.rhs))
            end
            return flatten(result)
        end
        proc(m, st::Assign)     = :($(st.x) = $(st.rhs))
        proc(m, st::Return)  = :(return $(st.rhs))
        proc(m, st::LineNumber) = nothing

        body = buildSource(m, proc) |> flatten

        kwargs = freeVariables(q) ∪ arguments(p)
        kwargsExpr = Expr(:tuple,kwargs...)

        stochExpr = begin
            vals = map(stochastic(m)) do x Expr(:(=), x,x) end
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
    x = merge(rand(q), _data)
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
