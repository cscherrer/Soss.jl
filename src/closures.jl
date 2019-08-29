using GG
using MacroTools:@q
using Soss
using MLStyle

struct WrapExpr{T}
    expr::Expr
end

wrap(expr) = WrapExpr{expr2typelevel(expr)}(expr)

unwrap(::WrapExpr{T}) where T = interpret(T)
unwrap(::Type{WrapExpr{T}}) where T = interpret(T)

function makeClosure(expr::Expr)
    wrap(expr) |> makeClosure
end

function _makeClosure(expr::Expr)
    @match expr begin
        :($x -> begin $(body...) end) => begin
            vs = setdiff(variables(body), [x]) |> Soss.astuple

            @gensym g
            (@q begin
                $g($vs, $x) = $(Expr(:block, body...))
                Closure{$g,typeof(vs)}
            end)
        end
    end
end


@generated function makeClosure(t::WrapExpr{T}) where T
    unwrap(t) |> _makeClosure
end

expr = :(a -> 2*a)
expr |> wrap |> typeof |> unwrap |> _makeClosure

mkcl(:(a -> 2*a))