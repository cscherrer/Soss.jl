using DataStructures

using Soss: Let, Follows, Return, LineNumber
using MacroTools
using MacroTools: @q, striplines
@reexport using Parameters
using IterTools

export fromcube
fromcube(dist, next) = quantile(dist, next())
fromcube(dist::iid, next) = [fromcube(dist.dist,next) for j in 1:dist.size]
fromcube(dist::For, next) = [fromcube(dist.f(x),next) for x in dist.xs]



export makeFromcube
function makeFromcube(m :: Model)
    fpre = @eval $(sourceFromcube(m))
    f(next;kwargs...) = Base.invokelatest(fpre, next; kwargs...)
end

export fromcube
fromcube(m::Model, next; kwargs...) = makeFromcube(m)(next;kwargs...)

function fromcube(m::Model, next, n::Int64; kwargs...)
    r = makeFromcube(m)
    [r(next;kwargs...) for j in 1:n] |> DataFrame

end


export sourceFromcube
function sourceFromcube(m::Model)
    m = canonical(m)

    @gensym next
    proc(m, st::Let)     = :($(st.x) = $(st.rhs))
    proc(m, st::Follows) = :($(st.x) = fromcube($(st.rhs), $next))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    body = buildSource(m, proc) |> striplines
    
    argsExpr = Expr(:tuple,freeVariables(m)...)

    stochExpr = begin
        vals = map(stochastic(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end
    
    @gensym fromcube
    
    flatten(@q (
        function $fromcube($next;kwargs...) 
            @unpack $argsExpr = kwargs
            # kwargs = Dict(kwargs)
            $body
            $stochExpr
        end
    ))

end


using Sobol


# function fromcubeExample()
#     m = @model begin
#         x ~ Normal(0,1)
#         y ~ Normal(x^2, 1) |> iid(3)
#     end

#     fpre = fromcube(m) |> eval
#     f(u;kwargs...) = Base.invokelatest(fpre,u; kwargs...)
    
#     s = SobolSeq(4)
#     u = hcat([next!(s) for i = 1:100]...)'
#     # f(u)
#     f(rand(4))
# end

# quantile.(iid.(3, Normal.(rand(100).^2, 1)), rand(3,100))
