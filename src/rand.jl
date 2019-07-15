@reexport using DataFrames

export sourceRand


export makeRand
function makeRand(m :: Model)
    fpre = @eval $(sourceRand(m))
    f(;kwargs...) = Base.invokelatest(fpre; kwargs...)
end

export rand
rand(m::Model; kwargs...) = makeRand(m)(;kwargs...)

function rand(m::Model, n::Int64; kwargs...)
    r = makeRand(m)
    [r(;kwargs...) for j in 1:n] # |> DataFrame

end

function sourceRand(m::Model)
    m = canonical(m)
    proc(m, st::Let)     = :($(st.x) = $(st.rhs))
    proc(m, st::Follows) = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    body = buildSource(m, proc) |> striplines
    
    argsExpr = Expr(:tuple,freeVariables(m)...)

    stochExpr = begin
        vals = map(variables(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    
    @gensym rand
    
    flatten(@q (
        function $rand(args...;kwargs...) 
            @unpack $argsExpr = kwargs
            $body
            $stochExpr
        end
    ))

end