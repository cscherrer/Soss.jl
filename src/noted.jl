using StructArrays

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
value(other) = other

export info
info(n::Noted) = N.info
info(other) = other

export values
values(s::StructArray{N}) where {N <: Noted} = s.value

export infos
infos(s::StructArray{N}) where {N <: Noted} = s.info



# s = StructArray{Noted}((randn(10),Fill(5,(10,))))

# r = StructArray{NamedTuple{(:a, :b, :c),Tuple{Float64,Float64,Float64}}}((randn(10),randn(10),randn(10)))
