
using GeneralizedGenerated: runtime_eval
using MacroTools: @q

export codegen

# moved to __init__
# @gg function codegen(_m::Model, _args, _data)
#     f = _codegen(type2model(_m))
#     :($f(_args, _data))
# end

function _codegen(m :: Model, expand_sums=true)
    s = symlogpdf(m)

    if expand_sums
        s = expandSums(s) |> foldConstants
    end 

    code = codegen(s)

    for (v, rhs) in pairs(m.vals)
        pushfirst!(code.args, :($v = $rhs))
    end

    for v in arguments(m)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_args, $vname)))
    end

    for v in stochastic(m)
        vname = QuoteNode(v)
        pushfirst!(code.args, :($v = getproperty(_data, $vname)))
    end


    f = mk_function(:((_args, _data) -> $code))

    return f
end

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

#         push!(body.args, eval(:(codegen(symlogpdf($_m)))))
#         return body
#     end
# end

export codegen
function codegen(s::Sym)
    r = codegen
    s.func == sympy.Add && begin
        @gensym add
        ex = @q begin 
            $add = 0.0
        end
        for arg in s.args
            t = r(arg)
            push!(ex.args, :($add += $t))
        end
        push!(ex.args, add)
        # @show ex
        return ex
    end


    s.func == sympy.Mul && begin
        @gensym mul
        ex = @q begin 
            $mul = 1.0
        end
        for arg in s.args
            t = r(arg)
            push!(ex.args, :($mul *= $t))
        end
        push!(ex.args, mul)
        return ex
    end

    s.func ∈ keys(symfuncs) && begin
        # @show s
        @gensym symfunc
        argnames = gensym.("arg" .* string.(1:length(s.args)))
        argvals = r.(s.args)
        ex = @q begin end
        for (k,v) in zip(argnames, argvals)
            push!(ex.args, :($k = $v))
        end
        f = symfuncs[s.func]
        push!(ex.args, :($symfunc = $f($(argnames...))))
        push!(ex.args, symfunc)
        return ex
    end

    s.func == sympy.Sum && begin
        @gensym sum
        @gensym Δsum
        @gensym lo 
        @gensym hi
        
        summand = r(s.args[1])

        ex = @q begin
            $Δsum = $summand
            $sum += $Δsum
        end
        
        for limits in s.args[2:end]
            (ix, ixlo, ixhi) = limits.args

            ex = @q begin
                $lo = $(r(ixlo))
                $hi = $(r(ixhi))
                @inbounds @fastmath for $(r(ix)) in $lo:$hi
                    $ex
                end
            end
        end
        
        ex = @q begin
            let 
                $sum = 0.0
                $ex
            $sum
            end
        end

        return ex
    end
    
    s.func == sympy.Symbol && return Symbol(string(s))
    s.func == sympy.Idx && return Symbol(string(s))        
    s.func == sympy.IndexedBase && return Symbol(string(s))

    # @show s
    return convert(Expr, s)
end


# julia> r(sym(:x) + sym(:y))
# quote
#     var"##add#407" = 0.0
#     var"##add#407" += x
#     var"##add#407" += y
#     var"##add#407"
# end