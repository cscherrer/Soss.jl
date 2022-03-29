struct None end
struct Just{T}
    value::T
end

Maybe{T} = Union{None, Just{T}} where {T}

maybe(f, m::None, default) = default
maybe(f, m::Just, default) = f(m.value) 

isJust(::None) = false
isJust(::Just) = true

isNone(::None) = true
isNone(::Just) = false

fromMaybe(m::Just, default) = m.value
fromMaybe(::None, default) = default

function qisdefined(x::Symbol)
    :($(Expr(:isdefined, x)))
end


function qmaybe(x::Symbol)
    isdef = Expr(:isdefined, x)
    :($isdef ? Just($x) : None())
end

macro qmaybe(s)
    esc(qmaybe(s))
end