import LogDensityProblems: logdensity
using ResumableFunctions

export arguments, args, stochastic, observed, parameters, supports
export paramSupport


using MacroTools: striplines, flatten, unresolve, resyntax, @q
using MacroTools
using StatsFuns
using DataStructures: counter

function symbols(expr)
    result = []
    postwalk(expr) do x
        if @capture(x, s_symbol_Symbol)
            union!(result, [s])
        end
    end
    result
end

export findsubexprs
function findsubexprs(expr, vs)
    intersect(symbols(expr), vs)
end




isNothing(x) = (x == Nothing)

rmNothing(x) = x

function rmNothing(x::Expr)
  # Do not strip the first argument to a macrocall, which is
  # required.
  if x.head == :macrocall && length(x.args) >= 2
    Expr(x.head, x.args[1:2]..., filter(x->!isNothing(x), x.args[3:end])...)
  else
    Expr(x.head, filter(x->!isNothing(x), x.args)...)
  end
end



