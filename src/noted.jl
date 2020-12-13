using StructArrays

abstract type AbstractNote{X,I} end

struct Noted{X,I}
    value :: X
    info :: I
end

function Base.show(io::IO, n::Noted)
    print(io, "Noted(")
    show(io, n.value)
    print(io, ", ")
    show(io, n.info)
    print(io, ")")
end

export value
value(n::Noted) = n.value
value(nt::NamedTuple) = nt.value
value(other) = other

export info
info(n::Noted) = n.info
info(other) = other

value(s::StructArray{N}) where {N <: Noted} = s.value

info(s::StructArray{N}) where {N <: Noted} = s.info



# s = StructArray{Noted}((randn(10),Fill(5,(10,))))

# r = StructArray{NamedTuple{(:a, :b, :c),Tuple{Float64,Float64,Float64}}}((randn(10),randn(10),randn(10)))

# StructArray{NamedTuple{(:a, :b),Tuple{Int64,NamedTuple{(:b1, :b2),Tuple{Int64,Int64}}}}}((rand(1:10,4),rand(1:10,4),rand(1:10,4)))


# StructArray{NamedTuple{(:a, :b),Tuple{Int64,NamedTuple{(:b1, :b2),Tuple{Int64,Int64}}}}}((rand(
    


# StructArray{NamedTuple{(:b1, :b2),Tuple{Int64,Int64}}}((rand(1:10,4),rand(1:10,4)))

# StructArray((1,2,3); names=(:a,:B,:c))
