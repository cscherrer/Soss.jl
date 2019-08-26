
export makeLogdensity
function makeLogdensity(m :: Model)
    fpre = sourceLogdensity(m) |> eval
    f(par) = invokefrozen(fpre, Real, par)
end


export logdensity
logdensity(m::Model, par) = makeLogdensity(m)(par)



export sourceLogdensity
function sourceLogdensity(m::Model; ℓ=:ℓ, fname = gensym(:logdensity))
    proc(m, st :: Observe)    = :($ℓ += logpdf($(st.rhs), $(m.data.x)))
    proc(m, st :: Sample)     = :($ℓ += logpdf($(st.rhs), $(st.x)))
    proc(m, st :: Assign)     = :($(st.x) = $(st.rhs))
    proc(m, st :: LineNumber) = nothing
    proc(::Nothing) = nothing

    unknowns = parameters(m) ∪ arguments(m)
    unkExpr = Expr(:tuple,unknowns...)

    unpack = @q begin end
    for p in unknowns
        push!(unpack.args, :($p = pars.$p))
    end

    wrap(kernel) = @q begin
        function $fname(pars)
            $unpack
            $ℓ = 0.0
            $kernel
            return $ℓ
        end
    end
    
    buildSource(m, :logdensity, proc, wrap) 
end

