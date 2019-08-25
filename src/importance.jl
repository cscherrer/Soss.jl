using Distributions
using MonteCarloMeasurements

export sourceImportanceSampler
function sourceImportanceSampler(p,q;ℓ=:ℓ)
    procp(p, st::Follows) = :($ℓ += logpdf($(st.rhs), $(st.x)))
    procp(p, st::Let)     = convert(Expr, st)
    procp(p, st::Return)  = nothing
    procp(p, st::LineNumber) = convert(Expr, st)

    procq(q, st::Follows) = @q begin
        $(st.x) = rand($(st.rhs))
        $ℓ -= logpdf($(st.rhs), $(st.x))
    end
    procq(q, st::Let)     = convert(Expr, st)
    procq(q, st::Return)  = nothing
    procq(q, st::LineNumber) = convert(Expr, st)

    pbody = buildSource(p, procp) |> striplines
    qbody = buildSource(q, procq) |> striplines

    kwargs = freeVariables(q) ∪ arguments(p)
    kwargsExpr = Expr(:tuple,kwargs...)

    stochExpr = begin
        vals = map(stochastic(q)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    
    @gensym logimportance
    result = @q function $logimportance(pars)
        @unpack $kwargsExpr = pars
        $ℓ = 0.0
        $qbody
        $pbody
        return ($ℓ, $stochExpr)
    end

    flatten(result)
end


export sourceParticleImportance
function sourceParticleImportance(p,q;ℓ=:ℓ)
    p = canonical(p)
    q = canonical(q)
    @gensym N
    # This determines how to initialize a Particle for a given expression
    vars(expr) = (bound(p) ∪ bound(q) ∪ stochastic(p) ∪ stochastic(q)) ∩ variables(expr)

    procp(p, st::Follows) = :($ℓ += logpdf($(st.rhs), $(st.x)))
    procp(p, st::Let)     = convert(Expr, st)
    procp(p, st::Return)  = nothing
    procp(p, st::LineNumber) = convert(Expr, st)

    function procq(q, st::Follows)
        if isempty(vars(st.rhs)) 
            @q begin
                $(st.x) = Particles($N, $(st.rhs))
                $ℓ -= logpdf($(st.rhs), $(st.x))
            end
        else
            @q begin
                $(st.x) = rand($(st.rhs))
                $ℓ -= logpdf($(st.rhs), $(st.x))
            end
        end
    end
    procq(q, st::Let)     = convert(Expr, st)
    procq(q, st::Return)  = nothing
    procq(q, st::LineNumber) = convert(Expr, st)

    pbody = buildSource(p, procp) |> striplines
    qbody = buildSource(q, procq) |> striplines

    kwargs = freeVariables(q) ∪ arguments(p)
    kwargsExpr = Expr(:tuple,kwargs...)

    stochExpr = begin 
        vals = map(stochastic(q)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    
    @gensym particleImportance
    result = @q function $particleImportance($N, pars)
        @unpack $kwargsExpr = pars
        $ℓ = 0.0 * Particles($N, Uniform())
        $qbody
        $pbody
        return ($ℓ, $stochExpr)
    end

    flatten(result)
end


    
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














export makeImportanceSampler
function makeImportanceSampler(p,q)
    fpre = @eval $(sourceImportanceSampler(p,q))

    function f(r;kwargs...) 
        qsample = r(;kwargs...)
        ℓ = Base.invokelatest(fpre, merge(kwargs, pairs(qsample)))
        return (qsample, ℓ)
    end

    return f
end

# p = @model μ begin
#     x ~ Normal(μ, 1)
# end

# q = @model μ begin
#     x ~ Cauchy(μ)
# end

# julia> sourceImportanceLogWeights(p,q)
# :(function ##logdensity#669(pars)
#       @unpack (x, μ) = pars
#       ℓ = 0.0
#       ℓ += logpdf(Normal(μ, 1), x)
#       ℓ -= logpdf(Cauchy(μ), x)
#       return ℓ
#   end)

# impsamp =  makeImportanceSampler(p,q)

# impsamp(;μ=3.0)
