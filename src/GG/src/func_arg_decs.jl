unset = Unset()

struct FuncArg
    name::Any
    type::Any
    default::Any
end

struct FuncHeader
    name::Any
    args::Any
    kwargs::Any
    ret::Any
    fresh::Any
end

FuncHeader() = FuncHeader(unset, unset, unset, unset, unset)

is_func_header(a::FuncHeader) = a.args != unset

function func_arg(@nospecialize(ex))::FuncArg
    @switch ex begin
        @case :(::$ty)
        @with func_arg(gensym("_")).type = ty
        @case :($var::$ty)
        @with func_arg(var).type = ty
        @case Expr(:kw, var, default)
        @with func_arg(var).default = default
        @case Expr(:(=), var, default)
        @with func_arg(var).default = default
        @case var::Symbol
        FuncArg(var, unset, unset)
        @case Expr(:..., _)
        error(
            "GG does not support variadic argument($ex) so far.\n" *
            "Try\n" *
            "  f(x...) = _f(x)\n" *
            "  @gg _f(x) = ...\n" *
            "See more at: https://github.com/JuliaStaging/GeneralizedGenerated.jl/issues/38",
        )
        @case _
        error("GG does not understand the argument $ex.")
    end
end

function func_header(@nospecialize(ex))::FuncHeader
    @switch ex begin
        @case :($hd::$ret)
        @with func_header(hd).ret = ret

        @case :($f($(args...); $(kwargs...)))
        inter = @with func_header(f).args = map(func_arg, args)
        @with inter.kwargs = map(func_arg, kwargs)

        @case :($f($(args...)))
        @with func_header(f).args = map(func_arg, args)

        @case :($f where {$(args...)})
        @with func_header(f).fresh = args

        @case Expr(:tuple, Expr(:parameters, kwargs...), args...)
        inter = @with FuncHeader().args = map(func_arg, args)
        @with inter.kwargs = map(func_arg, kwargs)

        @case Expr(:tuple, args...)
        @with FuncHeader().args = map(func_arg, args)

        @case f
        @with FuncHeader().name = f
    end
end

function of_args(::Unset)
    Argument[]
end

function of_args(args::AbstractArray{FuncArg})
    ret = Argument[]
    for (i, each) in enumerate(args)
        name = each.name === unset ? gensym("_$i") : each.name
        type = each.type === unset ? nothing : each.type
        arg = Argument(name, type, each.default)
        push!(ret, arg)
    end
    ret
end

extract_tvar(var::Union{Symbol,Expr})::Symbol = @match var begin
    :($a <: $_) => a
    :($a >: $_) => a
    :($_ >: $a >: $_) => a
    :($_ <: $a <: $_) => a
    a::Symbol => a
end
