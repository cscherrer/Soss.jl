using IRTools
using SymbolicUtils: term
using MacroTools: isexpr
using SymbolicUtils
using SymbolicCodegen

struct SymCall{D}
    dict::D
end

function _symcall(s::SymCall, f, args...)
    dict = s.dict
    applicable(f, args...) || return symterm(dict, f, args...)
    return s(f, args...)
end

function symterm(dict, f, args...)
    constargs = (SymbolicCodegen.toconst(arg, dict) for arg in args)
    T = typeof(f(constargs...))
    term(f, args...; type=T)
end

IRTools.@dynamo function (s::SymCall)(a...) 
    ir = IRTools.IR(a...)
    ir == nothing && return
    for (x, st) in ir
        isexpr(st.expr, :call) || continue
        ir[x] = IRTools.xcall(_symcall, IRTools.self, st.expr.args...)
    end
    return ir
end


# EXAMPLE

# f(x::Real) = x+1
# h(x) = x^2 + 2
# g(x) = h(x) + f(x)

# @syms x::Int

# dict = Dict(:x => 3)
# using SymbolicUtils: symtype
# s = SymCall(dict)(g,x) 
# symtype(s)
