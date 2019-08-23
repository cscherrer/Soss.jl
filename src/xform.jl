using Reexport

@reexport using DataFrames
using MLStyle
using Distributions

export sourceXform

function sourceXform(m::Model)
    m = canonical(m)
    pars = parameters(m)
    @gensym t result

    proc(m, st::Assign)        = :($(st.x) = $(st.rhs))
    proc(m, st::Return)     = nothing
    proc(m, st::LineNumber) = nothing
    proc(m, st::Observe)    = :($(st.x) = rand($(st.rhs)))
    
    function proc(m, st::Sample)
        @q begin
                $(st.x) = rand($(st.rhs))
                $t = xform($(st.rhs))

                $result = merge($result, ($(st.x)=$t,))
        end
    end

    body = buildSource(m, proc) |> striplines
    
    argsExpr = Expr(:tuple,arguments(m)...)

    
    @gensym rand
    
    flatten(@q (
        function $rand(args...) 
            $result = NamedTuple()
            $body
            as($result)
        end
    ))

end


export makeXform
function makeXform(m :: Model)
    fpre = @eval $(sourceXform(m))
    f(;kwargs...) = Base.invokelatest(fpre)
end

export xform
xform(m::Model) = makeXform(m)()




function xform(d)
    if hasmethod(support, (typeof(d),))
        return asTransform(support(d)) 
    end
end

function asTransform(supp:: RealInterval) 
    (lb, ub) = (supp.lb, supp.ub)

    (lb, ub) == (-Inf, Inf) && (return asℝ)
    (lb, ub) == (0.0,  Inf) && (return asℝ₊)
    (lb, ub) == (0.0,  1.0) && (return as𝕀)
    error("asTransform($supp) not yet supported")
end

# export xform
# xform(::Normal)       = asℝ
# xform(::Cauchy)       = asℝ
# xform(::Flat)         = asℝ

# xform(::HalfCauchy)   = asℝ₊
# xform(::HalfNormal)   = asℝ₊
# xform(::HalfFlat)     = asℝ₊
# xform(::InverseGamma) = asℝ₊
# xform(::Gamma)        = asℝ₊
# xform(::Exponential)  = asℝ₊

# xform(::Beta)         = as𝕀
# xform(::Uniform)      = as𝕀




function xform(d::For)
    # allequal(d.f.(d.θs)) && 
    return as(Array, xform(d.f(d.θs[1])), size(d.θs)...)
    
    # TODO: Implement case of unequal supports
    @error "xform: Unequal supports not yet supported"
end

function xform(d::iid)
    as(Array, xform(d.dist), d.size...)
end
