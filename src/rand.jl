@reexport using DataFrames

using GG

export rand
# @generated function rand(m::Model{T} where T)
#     @match m begin
#         ::Type{Model{T}} where {T}  => begin
#             m2 = interpret(T)
#             r = Model(m2) |> sourceRand
#             # @show r 
#             r
#         end
#     end
# end

@generated function rand(m::Model{T} where T) 
    modeltype(m) |> interpret |> Model |> sourceRand
end

export sourceRand
function sourceRand(m::Model{T} where T)
    m = canonical(m)
    proc(m, st::Assign)  = :($(st.x) = $(st.rhs))
    proc(m, st::Sample)  = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Observe) = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    stochExpr = begin
        vals = map(variables(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end

    wrap(kernel) = @q begin
        # @show Base.@locals
        # @show @__MODULE__
        $kernel
        $stochExpr
    end
    
    buildSource(m, :rand, proc, wrap) |> flatten
end