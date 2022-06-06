@generated function field_update(main::T, field::Val{Field}, value) where {T,Field}
    fields = fieldnames(T)
    quote
        $T($([field !== Field ? :(main.$field) : :value for field in fields]...))
    end
end

function lens_compile(ex, cache, value)
    @when :($a.$(b::Symbol).$(c::Symbol) = $d) = ex begin
        updated = Expr(
            :let,
            Expr(:block, :($cache = $cache.$b), :($value = $d)),
            :($field_update($cache, $(Val(c)), $value)),
        )
        lens_compile(:($a.$b = $updated), cache, value)
        @when :($a.$(b::Symbol) = $c) = ex
        Expr(
            :let,
            Expr(:block, :($cache = $a), :($value = $c)),
            :($field_update($cache, $(Val(b)), $value)),
        )
        @otherwise
        error("Malformed update notation $ex, expect the form like 'a.b = c'.")
    end
end

function with(ex)
    cache = gensym("cache")
    value = gensym("value")
    lens_compile(ex, cache, value)
end

macro with(ex)
    esc(with(ex))
end
