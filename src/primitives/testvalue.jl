using TupleVectors: chainvec
import MeasureTheory: testvalue

export testvalue
EmptyNTtype = NamedTuple{(),Tuple{}} where T<:Tuple

# function testvalue(d::ConditionalModel, N::Int)
#     r = chainvec(testvalue(d), N)
#     for j in 2:N
#         @inbounds r[j] = testvalue(d)
#     end
#     return r
# end

# testvalue(d::ConditionalModel, N::Int) = testvalue(d, N)

@inline function testvalue(c::ConditionalModel)
    m = Model(c)
    return _testvalue(getmoduletypencoding(m), m, argvals(c))
end

@inline function testvalue(m::Model)
    return _testvalue(getmoduletypencoding(m), m, NamedTuple())
end




sourceTestvalue(m::Model) = sourceTestvalue()(m)
sourceTestvalue(jd::ConditionalModel) = sourceTestvalue(jd.model)

export sourceTestvalue
function sourceTestvalue() 
    function(_m::Model)
        proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
        proc(_m, st::Sample)  = :($(st.x) = testvalue($(st.rhs)))
        proc(_m, st::Return)  = :(return $(st.rhs))
        proc(_m, st::LineNumber) = nothing

        vals = map(x -> Expr(:(=), x,x),parameters(_m)) 

        wrap(kernel) = @q begin
            $kernel
            $(Expr(:tuple, vals...))
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

@gg function _testvalue(M::Type{<:TypeLevel}, _m::Model, _args)
    body = type2model(_m) |> sourceTestvalue() |> loadvals(_args, NamedTuple())
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end

@gg function _testvalue(M::Type{<:TypeLevel}, _m::Model, _args::NamedTuple{()})
    body = type2model(_m) |> sourceTestvalue()
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end
