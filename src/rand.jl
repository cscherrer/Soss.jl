@reexport using DataFrames

export sourceRand


export makeRand
function makeRand(m :: Model)
    ast = sourceRand(m)
    FuncRand{expr2typelevel(ast)}()
end

export rand
rand(m::Model) = makeRand(m)()

function rand(m::Model, n::Int64; kwargs...)
    r = makeRand(m)
    [r(;kwargs...) for j in 1:n] # |> DataFrame

end

struct FuncRand{AST} end

@generated function (::FuncRand{AST})() where AST
    interpret(AST)
end

function sourceRand(m::Model)
    m = canonical(m)
    proc(m, st::Assign)     = :($(st.x) = $(st.rhs))
    proc(m, st::Sample) = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Observe) = :($(st.x) = rand($(st.rhs)))
    proc(m, st::Return)  = :(return $(st.rhs))
    proc(m, st::LineNumber) = nothing

    body = buildSource(m, proc) |> striplines

    argsExpr = Expr(:tuple,freeVariables(m)...)

    stochExpr = begin
        vals = map(variables(m)) do x Expr(:(=), x,x) end
        Expr(:tuple, vals...)
    end

    ast = flatten(@q (
        begin
            $body
            $stochExpr
        end
    ))

    

end