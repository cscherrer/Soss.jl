using Accessors
using Accessors: IndexLens, PropertyLens, ComposedOptic
using BangBang

struct Lens!!{L}
    pure::L
end

(l::Lens!!)(o) = l.pure(o)

@inline function Accessors.set(o, l::Lens!!{<: ComposedOptic}, val)
    set(o, Lens!!(l.pure.outer) ∘ Lens!!(l.pure.inner), val)
end

@inline function Accessors.set(o, l::Lens!!{PropertyLens{prop}}, val) where {prop}
    setproperty!!(o, prop, val)
end

@inline Accessors.set(o, l::Lens!!{typeof(identity)}, val) = val

@inline function Accessors.set(o, l::Lens!!{<:IndexLens}, val)
    setindex!!(o, val, l.pure.indices...)
end

@inline function Accessors.modify(f, o, l::Lens!!)
    set(o, l, f(l(o)))
end

@inline function Accessors.modify(f, o, l::Lens!!{<:ComposedOptic})
    o_inner = l.pure.inner(o)
    modify(f, o_inner, Lens!!(l.pure.outer))
end

using Accessors: setmacro, opticmacro, modifymacro

macro set!!(ex)
    setmacro(Lens!!, ex; overwrite=true)
end

macro optic!!(ex)
    opticmacro(Lens!!, ex)
end

macro modify!!(f, ex)
    modifymacro(Lens!!, f, ex)
end

###############################################################################

function unescape(ast)
    leaf(x) = x
    @inline function branch(f, head, args)
        default() = Expr(head, map(f, args)...)
        
        head == :escape ? f(args[1]) : default()
    end
    foldast(leaf, branch)(ast)
end

function opticize(ast)
    leaf(x) = x
    @inline function branch(f, head, args)
        default() = Expr(head, map(f, args)...)
        head == :call || return default()
        first(args) == :~ || return default()
        length(args) == 3 || return default()

        # If we get here, we know we're working with something like `lhs ~ rhs`
        lhs = args[2]
        rhs = args[3]
        
        lhs′ = @match lhs begin
            :(($(x::Symbol), $o)) => :(($x, $o))
            :(($(x::Var), $o)) => :(($x, $o))
            _ => begin
                (x, o) = unescape.(Accessors.parse_obj_optic(lhs))
                :(($x, $o))
            end
        end
        rhs′ = f(rhs)
        :($lhs′ ~ $rhs′)
    end

    foldast(leaf, branch)(ast)
end