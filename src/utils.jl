export arguments, LogisticBinomial, HalfCauchy

using MacroTools: striplines, flatten, unresolve, resyntax, @q
using MacroTools
using StatsFuns

function nobegin(ex)
    postwalk(ex) do x
        if @capture(x, begin body__ end)
            unblock(x)
        else
            x
        end
    end
end

pretty = striplines



function parameters(model)
    params :: Vector{Symbol} = []
    body = postwalk(model) do x
        if @capture(x, v_ ~ dist_)
            push!(params, v)
        else x
        end
    end
    return params
end

function supports(model)
    supps = Dict{Symbol, Any}()
    postwalk(model) do x
        if @capture(x, v_ ~ dist_)
            supps[v] = support(eval(dist))
        else x
        end
    end
    return supps
end

function xform(R, v, supp)
    @assert typeof(supp) == RealInterval
    lo = supp.lb
    hi = supp.ub
    body = if (lo,hi) == (-Inf, Inf)  # no transform needed in this case
        quote
            $v = $R
        end
    elseif (lo,hi) == (0.0, Inf)   
        quote
            $v = softplus($R)
            ℓ += abs($v - $R)
        end
    elseif (lo, hi) == (0.0, 1.0)
        quote 
            $v = logistic($R)
            ℓ += log($v * (1 - $v))
        end  
    else 
        throw(error("Transform not implemented"))                            
    end

    return body
end

function logdensity(model)
    j = 0
    body = postwalk(model) do x
        if @capture(x, v_ ~ dist_)
            j += 1
            supp = support(eval(dist)) 
            @assert (typeof(supp) == RealInterval) "Sampled values must have RealInterval support (for now)"
            quote
                $(xform(:(θ[$j]), v, supp ))
                ℓ += logpdf($dist, $v)
            end
        elseif @capture(x, v_ <~ dist_) 
            quote
                ℓ += logpdf($dist, $v)
            end
        else x
        end
    end
    fQuoted = quote
        function(θ::SVector{$j,Float64}, DATA)
            ℓ = 0.0
            $body
            return ℓ
        end
    end

    return pretty(fQuoted)
end

function mapbody(f,functionExpr)
    ans = deepcopy(functionExpr)
    ans.args[2] = f(ans.args[2])
    ans
end

function samp(m)
    func = postwalk(m) do x
        if @capture(x, v_ ~ dist_) 
            @q begin
                $v = rand($dist)
                val = merge(val, ($v=$v,))
            end
        else x
        end
    end

    mapbody(func) do body
        @q begin
            val = NamedTuple()
            $body
            val
        end
    end
end;

sampleFrom(m) = eval(samp(m))


HalfCauchy(s) = Truncated(Cauchy(0,s),0,Inf)

# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n,x)=Binomial(n,logistic(x))

    end

end

HalfCauchy(s) = Truncated(Cauchy(0,s),0,Inf)

# Binomial distribution, parameterized by logit(p)
LogisticBinomial(n,x)=Binomial(n,logistic(x))

