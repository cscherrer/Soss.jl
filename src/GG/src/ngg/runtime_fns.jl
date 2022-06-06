struct RuntimeFn{Args,Kwargs,Body,Name} end
struct Unset end

Base.show(io::IO, rtfn::RuntimeFn{Args,Kwargs,Body,Name}) where {Args,Kwargs,Body,Name} =
    begin
        args = from_type(Args)
        kwargs = from_type(Kwargs)
        args = join(map(string, args), ", ")
        kwargs = join(map(string, kwargs), ", ")
        body = from_type(Body) |> rmlines
        repr = "$Name = ($args;$kwargs) -> $body"
        print(io, repr)
    end

Base.show(io::IO, ::Type{RuntimeFn{Args,Kwargs,Body,Name}}) where {Args,Kwargs,Body,Name} =
    print(io, "ggfunc-$Name")

struct Argument
    name::Symbol
    type::Union{Nothing,Any}
    default::Union{Unset,Any}
end

function compress_impl!(arg::Argument)
    meta, default = compress_impl!(arg.default)
    encoded = Call(
        Constructor{Argument}(),
        tuple(compress(arg.name), compress(arg.type), default),
    )
    may_cache_call(meta, encoded)
end

Base.show(io::IO, arg::Argument) = begin
    print(io, arg.name)
    if arg.type !== nothing
        print(io, "::", arg.type)
    end
    if arg.default !== Unset()
        print(io, "=", arg.default)
    end
end

function _ass_positional_args!(
    assign_block::Vector{Expr},
    args::List{Argument},
    ninput::Int,
    pargs::Symbol,
)
    i = 1
    for arg in args
        ass = arg.name
        if arg.type !== nothing
            ass = :($ass::$(arg.type))
        end
        if i > ninput
            arg.default === Unset() && error("Input arguments too few.")
            ass = :($ass = $(arg.default))
        else
            ass = :($ass = $pargs[$i])
        end
        push!(assign_block, ass)
        i += 1
    end
end

const _zero_arg = compress(list(Argument))
@generated function (::RuntimeFn{Args,_zero_arg,Body})(pargs...) where {Args,Body}
    args = from_type(Args)
    ninput = length(pargs)
    assign_block = Expr[]
    body = from_type(Body)
    _ass_positional_args!(assign_block, args, ninput, :pargs)
    quote
        let $(assign_block...)
            $body
        end
    end
end

_get_kwds(::Type{Base.Iterators.Pairs{A,B,C,NamedTuple{Kwds,D}}}) where {Kwds,A,B,C,D} =
    Kwds

@generated function (::RuntimeFn{Args,Kwargs,Body})(
    pargs...;
    pkwargs...,
) where {Args,Kwargs,Body}
    args = from_type(Args)
    kwargs = from_type(Kwargs)
    ninput = length(pargs)
    assign_block = Expr[]
    body = from_type(Body)
    if isempty(kwargs)
        _ass_positional_args!(assign_block, args, ninput, :pargs)
    else
        kwds = gensym("kwds")
        feed_in_kwds = _get_kwds(pkwargs)
        push!(assign_block, :($kwds = pkwargs))
        _ass_positional_args!(assign_block, args, ninput, :pargs)
        for kwarg in kwargs
            ass = k = kwarg.name
            if kwarg.type !== nothing
                ass = :($ass::$(kwarg.type))
            end
            if k in feed_in_kwds
                ass = :($ass = $kwds[$(QuoteNode(k))])
            else
                default = kwarg.default
                default === Unset() && error("no default value for keyword argument $(k)")
                ass = :($ass = $default)
            end
            push!(assign_block, ass)
        end
    end
    quote
        let $(assign_block...)
            $body
        end
    end
end
