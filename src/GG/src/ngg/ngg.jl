"""
Providing *naive generalized generated* functions.
"""
module NGG
export to_type, from_type, TypeLevel
export compress, decompress
export RuntimeFn, Unset, Argument, mkngg, rmlines
using DataStructures
const List = LinkedList

rmlines(ex::Expr) = begin
    hd = ex.head
    tl = map(rmlines, filter(!islinenumbernode, ex.args))
    Expr(hd, tl...)
end
rmlines(@nospecialize(a)) = a
islinenumbernode(@nospecialize(x)) = x isa LineNumberNode

include("typeable.jl")
include("runtime_fns.jl")

"""
julia> using .NGG
julia> mkngg(
           :f, #fname
           [
               Argument(:a, nothing, Unset()),
               Argument(:b, nothing, Unset())
           ],  # args
           Argument[], # kwargs
           :(a + b) #expression
       )
f = (a, b;) -> a + b

julia> ans(1, 2)
3
"""
function mkngg(
    name::Symbol,
    args::Vector{Argument},
    kwargs::Vector{Argument},
    @nospecialize(ex)
)
    Args = to_type(_typed_list(Argument, args...))
    Kwargs = to_type(_typed_list(Argument, kwargs...))
    Ex = to_type(ex)
    RuntimeFn{Args,Kwargs,Ex,name}()
end

# const f = mkngg(
#     :f, #fname
#     [
#         Argument(:a, nothing, Unset()),
#         Argument(:b, nothing, Unset())
#     ],  # args
#     Argument[], # kwargs
#     :(a + b) #expression
# )

# println(f)
# println(typeof(f))
# using BenchmarkTools

# @btime f(1, 2)

end
