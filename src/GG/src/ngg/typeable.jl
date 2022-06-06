using Serialization
# using DataStructures
# const List = LinkedList

@nospecialize
include("compact.jl")

function _typed_list(::Type{T}, args::T...) where {T}
    foldr(args, init = nil(T)) do e, last
        cons(e, last)
    end
end

function compress_impl!(xs::List{T}) where {T}
    args = Any[]
    maxcomplexity = 0
    for x in collect(xs)
        meta, arg = compress_impl!(x)
        push!(args, arg)
        maxcomplexity += meta.complexity
    end
    encoded = Call(Constructor{_typed_list}(), (compress(T), args...))
    may_cache_call(SimpleMeta(maxcomplexity), encoded)
end

struct Buf{N}
    units::NTuple{N,UInt8}
end

Base.show(io::IO, buf::Buf{N}) where {N} = Base.show(io, "Buf{$N}()")

struct TypeLevel{T,BufData} end

function from_type(::Type{TypeLevel{T,BufData}}) where {T,BufData}
    compressed = deserialize(IOBuffer(UInt8[BufData.units...]))
    decompress(compressed)::T
end

function to_type(x::T) where {T}
    io = IOBuffer()
    serialize(io, compress(x))
    seek(io, 0)
    TypeLevel{T,Buf(Tuple(take!(io)))}
end

function Base.show(io::IO, ::T) where {T<:TypeLevel}
    print(io, "TypeEncoding(")
    Base.show(io, from_type(T))
    print(io, ")")
end

# xs = to_type(
#     quote
#         f
#         $(list(1, 2, 3))
#     end
# )()

# println(xs)
# println(CallPool)
# println(RefValPool)
# println(ExprPool)

@specialize
