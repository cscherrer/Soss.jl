
using GeneralizedGenerated: runtime_eval
using MacroTools: @q

# export codegen

function makeℓ(cm::ConditionalModel{A,B,M}) where {A,B,M}
    
    s = symlogdensity(cm)
    
end



# function substitute_constants(s, known)








# moved to __init__
@gg function codegen(_m::Model, _args, _data)
    f = csecodegen(type2model(_m))
    :($f(_args, _data))
end

function sourceCodegen(cm :: ConditionalModel)
    s = symlogdensity(cm)

    code = codegen(s)

    m = Model(cm)
    for (v, rhs) in pairs(m.vals)
        pushfirst!(code.args, :($v = $rhs))
    end

    for v in arguments(m)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_args, $vname)))
    end

    for v in sampled(m)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_data, $vname)))
    end

    code = MacroTools.flatten(code)

    f = mk_function(:((_args, _data) -> $code))

    return f
end

codegen(a::AbstractArray) = a

function codegen(::Type{T}, f::Function, args::Array{Sym}) where {T}
    ts = codegen.(args)
    @q begin
        $f($(ts...))
    end
end

codegen(s::T) where T <: Number = s

codegen(s::Symbol) = s
codegen(ex::Expr) = ex

function codegen(s::Term{T}) where {T}
    args = codegen.(s.arguments)
    codegen(T, s.f, args...)
end

function codegen(s::Sym{T}) where {T}
    s.name
end

function codegen(::Type{T}, f::Function, args...) where {T}
    ts = codegen.(args)
    @q begin
        $f($(ts...))
    end
end

function codegen(::Type{T},::typeof(*), args...) where {T <: Number}
    @gensym mul
    ex = @q begin
        $mul = 1.0
    end
    for arg in args
        t = codegen(arg)
        push!(ex.args, :($mul *= $t))
    end
    push!(ex.args, mul)
    return ex
end

function codegen(::Type{T},::typeof(+), args...) where {T <: Number}
    @gensym add
    ex = @q begin
        $add = 0.0
    end
    for arg in args
        t = codegen(arg)
        push!(ex.args, :($add += $t))
    end
    push!(ex.args, add)
    return ex
end

function codegen(::Type{T},s::SymbolicUtils.Sym{SymbolicUtils.FnType{Tuple{E,Int64,Int64,Int64},X}}, args...) where {T, E<: Number, X <: Number}
    @assert s.name == :Sum

    @gensym sum
    @gensym Δsum
    @gensym lo
    @gensym hi
        
    (summand, ix, ixlo, ixhi) = codegen.(args)


    ex = @q begin
        $Δsum = $summand
        $sum += $Δsum
    end

    # Originally this part was in a `for` loop to allow for nested sums
    ex = @q begin
        $lo = $(ixlo)
        $hi = $(ixhi)
        @inbounds @fastmath for $(ix) in $lo:$hi
            $ex
        end
    end

    ex = @q begin
        $sum = 0.0
        $ex
        $sum
    end

    return ex
end




# function codegen(s::Sym)
#     r = codegen
    

#     s.func ∈ keys(symfuncs) && begin
#         # @show s
#         @gensym symfunc
#         argnames = gensym.("arg" .* string.(1:length(s.args)))
#         argvals = r.(s.args)
#         ex = @q begin end
#         for (k,v) in zip(argnames, argvals)
#             push!(ex.args, :($k = $v))
#         end
#         f = symfuncs[s.func]
#         push!(ex.args, :($symfunc = $f($(argnames...))))
#         push!(ex.args, symfunc)
#         return ex
#     end

    

#     s.func == sympy.Symbol && return Symbol(string(s))
#     s.func == sympy.Idx && return Symbol(string(s))
#     s.func == sympy.IndexedBase && return Symbol(string(s))

#     # @show s
#     return convert(Expr, s)
# end


# julia> r(sym(:x) + sym(:y))
# quote
#     var"##add#407" = 0.0
#     var"##add#407" += x
#     var"##add#407" += y
#     var"##add#407"
# end


# @generated function _codegen(_m::Model, _args, _data)
#     type2model(_m) |> sourceCodegen() |> loadvals(_args, _data)
# end

# export sourceCodegen
# function sourceCodegen()
#     function(_m::Model)
#         body = @q begin end

#         for (x, rhs) in pairs(_m.vals)
#             push!(body.args, :($x = $rhs))
#         end

#         push!(body.args, eval(:(codegen(symlogdensity($_m)))))
#         return body
#     end
# end

# export codegen

# function codegen end

# function logdensity(m::ConditionalModel{A0,A,B,M},x,::typeof(codegen)) where {A0,A,B,M}
#     codegen(M, m.model, m.args, x)
# end


# function codegen(T::Type, ::Sym{FnType{Tuple{Int64},Float64}}, ::Sym{Int64})

export codegen
function codegen(cm :: ConditionalModel)
    assignments = cse(symlogdensity(cm))

    q = @q begin end

    for a in assignments
        x = a[1]
        rhs = codegen(a[2])
        push!(q.args, @q begin $x = $rhs end)
    end

    MacroTools.flatten(q)
end
