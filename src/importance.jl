
export sourceImportanceLogWeights
function sourceImportanceLogWeights(p,q;ℓ=:ℓ)
    pbody = postwalk(p.body) do x
        if @capture(x, v_ ~ dist_)
            @q begin
                $ℓ += logpdf($dist, $v)
            end
        else x
        end
    end
    qbody = postwalk(q.body) do x
        if @capture(x, v_ ~ dist_)
            @q begin
                $ℓ -= logpdf($dist, $v)
            end
        else x
        end
    end

    unknowns = parameters(p) ∪ arguments(p) ∪ parameters(q) ∪ arguments(q)
    unkExpr = Expr(:tuple,unknowns...)
    @gensym logimportance
    result = @q function $logimportance(pars)
        @unpack $(unkExpr) = pars
        $ℓ = 0.0

        $pbody
        $qbody
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
