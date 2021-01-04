function codegen(s::Term{T}) where {T}
    codegen(T, s.f, s.arguments...)
end

function codegen(s::Sym{T}) where {T}
    s.name
end

function codegen(::Type{T},::typeof(*), args...) where {T <: Number}
    @gensym mul
    ex = @q begin
        $mul = 1.0
    end
    for arg in args
        t = codegen(arg)
        push!(ex.args, :($mul += $t))
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

function codegen(::Type{T},::SymbolicUtils.Sym{SymbolicUtils.FnType{NTuple{4,A},X}}, args...) where {T<:Number,A<:Number,X<:Number}
    @assert s.f.name == :Sum

    begin
    @gensym sum
    @gensym Δsum
    @gensym lo
    @gensym hi

 
    summand = codegen(args[1])
        
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
        let $sum = 0.0,
            $ex
            $sum
        end
    end

    return ex
end


function codegen(s::Sym)
    r = codegen
    

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
