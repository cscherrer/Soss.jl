using Distributions

export sourceImportanceLogWeights
function sourceImportanceLogWeights(p,q;ℓ=:ℓ)
    procp(p, st::Follows) = :($ℓ += logpdf($(st.rhs), $(st.x)))
    procp(p, st::Let)     = convert(Expr, st)
    procp(p, st::Return)  = nothing
    procp(p, st::LineNumber) = convert(Expr, st)

    procq(q, st::Follows) = @q begin
        $ℓ -= logpdf($(st.rhs), $(st.x))
    end
    procq(q, st::Let)     = convert(Expr, st)
    procq(q, st::Return)  = nothing
    procq(q, st::LineNumber) = convert(Expr, st)

    pbody = buildSource(p, procp) |> striplines
    qbody = buildSource(q, procq) |> striplines
    
    
    unknowns = parameters(p) ∪ arguments(p) ∪ parameters(q) ∪ arguments(q)
    unkExpr = Expr(:tuple,unknowns...)
    @gensym logimportance
    result = @q function $logimportance(pars)
        @unpack $(unkExpr) = pars
        $ℓ = 0.0
        $qbody
        $pbody
        return $ℓ
    end

    flatten(result)
end

export makeImportanceSampler
function makeImportanceSampler(p,q)
    r = makeRand(q)
    fpre = @eval $(sourceImportanceLogWeights(p,q))

    function f(;kwargs...) 
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
