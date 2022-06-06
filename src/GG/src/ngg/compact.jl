using Base.Threads: lock, unlock, SpinLock
const _lock = SpinLock()

const CacheComplexityThres = 32
const CacheComplexityDepthFactor = 2
const RevShiftBits = 2
const ShiftBits = sizeof(UInt) * 8 - RevShiftBits

const HAS_FLAGS = UInt(0b11) << ShiftBits
struct BitsValue{L}
    value::L
end

const FLAGS = (Any = UInt(0), Expr = UInt(1), Call = UInt(2))

const CompactExpr{Args} = Tuple{Symbol,Args}

const RefValPool = Any[]
const RefValIndex = Base.IdDict{Any,UInt}()

const ExprPool = CompactExpr[]
const ExprIndex = Dict{CompactExpr,UInt}()

struct Call{F,Args<:Tuple}
    f::F
    args::Args
end

const CallPool = Call[]
const CallIndex = Dict{Call,UInt}()

struct ExprMeta
    complexity::Int
    inner_lns::Vector{Tuple{Int,ExprMeta}}
    lns::Vector{Tuple{Int,LineNumberNode}}
end

struct SimpleMeta
    complexity::Int
end

SimpleMeta(meta::ExprMeta) = SimpleMeta(meta.complexity)
SimpleMeta(meta::SimpleMeta) = meta

const leaf_meta = SimpleMeta(0)

@nospecialize

function _assign_id(pool::AbstractVector, flag::UInt)
    i = length(pool)
    if iszero(i & HAS_FLAGS)
        return UInt(i) | (flag << ShiftBits)
    else
        throw(OverflowError("pool too long"))
    end
end

@static if VERSION < v"1.1"
    function _get!(default::Function, d::Base.IdDict{K,V}, @nospecialize(key)) where {K,V}
        val = get(d, key, Base.secret_table_token)
        if val === Base.secret_table_token
            val = default()
            if !isa(val, V)
                val = convert(V, val)::V
            end
            setindex!(d, val, key)
            return val
        else
            return val::V
        end
    end
end

_get!(f, d, key) = get!(f, d, key)

function _get_id!(pool, index, val, flag)
    lock(_lock)
    try
        _get!(index, val) do
            id = _assign_id(pool, flag)
            push!(pool, val)
            index[val] = id
            id
        end
    finally
        unlock(_lock)
    end
end

function _lookup!(pool, idx::Integer)
    lock(_lock)
    try
        pool[idx]
    finally
        unlock(_lock)
    end
end

function compress_impl!(val::Ptr{T}) where {T}
    leaf_meta, Call(Constructor{Ptr{T}}(), tuple(BitsValue(UInt(val))))
end

function compress_impl!(val)
    if isbits(val)
        leaf_meta, BitsValue(val)
    else
        leaf_meta, _get_id!(RefValPool, RefValIndex, val, FLAGS.Any)
    end
end

compress_impl!(val::Symbol) = (leaf_meta, val)
function compress_impl!(ex::Expr)
    args = Any[]
    inner_lns = Tuple{Int,ExprMeta}[]
    lns = Tuple{Int,LineNumberNode}[]
    i = 0
    maxcomplexity = 1
    for each in ex.args
        if each isa LineNumberNode
            push!(lns, (i, each))
        else
            i += 1
            meta, a = compress_impl!(each)
            push!(args, a)
            if meta !== leaf_meta # leaf
                if meta isa SimpleMeta || isempty(meta.inner_lns) && isempty(meta.lns)
                else
                    push!(inner_lns, (i, meta))
                end
                maxcomplexity =
                    max(meta.complexity + CacheComplexityDepthFactor, maxcomplexity)
            end
        end
    end

    base = (ex.head, Tuple(args))
    if maxcomplexity < CacheComplexityThres
        base = _get_id!(ExprPool, ExprIndex, base, FLAGS.Expr)
    end
    ExprMeta(maxcomplexity, inner_lns, lns), base
end

function ln_to_tuple(ln::LineNumberNode)
    (ln.line, Symbol(ln.file))
end

function meta_to_tuple(meta::ExprMeta)
    Tuple((i, meta_to_tuple(m)) for (i, m) in meta.inner_lns),
    Tuple((i, ln_to_tuple(l)) for (i, l) in meta.lns)
end

function compress(val)
    meta, encoded = compress_impl!(val)
    meta isa SimpleMeta && return encoded
    (meta_to_tuple(meta), encoded)
end

decompress_impl(encoded::Symbol, ::Tuple) = encoded
decompress_impl(encoded::BitsValue, ::Tuple) = encoded.value

function decompress_impl(encoded::UInt, meta::Tuple)
    flag = (encoded >> ShiftBits)
    if flag == FLAGS.Any
        return _lookup!(RefValPool, (encoded << RevShiftBits >> RevShiftBits) + 1)
    elseif flag == FLAGS.Expr
        encoded = _lookup!(ExprPool, (encoded << RevShiftBits >> RevShiftBits) + 1)
        return decompress_impl(encoded, meta)
    elseif flag == FLAGS.Call
        encoded = _lookup!(CallPool, (encoded << RevShiftBits >> RevShiftBits) + 1)
        return decompress_impl(encoded, meta)
    else
        error("invalid flag $flag")
    end
end

function get_from_tuple(xs::Tuple, key, default)
    for (k, v) in xs
        k == key && return v
    end
    return default
end

function decompress_impl(encoded::Call, ::Tuple)
    f = encoded.f
    args = decompress.(encoded.args)
    f(args...)
end

function decompress_impl(encoded::Tuple, meta::Tuple)
    inner_lns, lns = meta
    head, args = encoded
    ex = Expr(head)
    j = 1
    for i in eachindex(args)
        while j <= length(lns) && lns[j][1] < i
            line, file = lns[j][2]
            push!(ex.args, LineNumberNode(line, file))
            j += 1
        end
        default_meta = ((), ())
        push!(ex.args, decompress_impl(args[i], get_from_tuple(inner_lns, i, default_meta)))
    end
    ex
end

function decompress(encoded::Tuple)
    meta, encoded = encoded
    decompress_impl(encoded, meta)
end


function decompress(encoded)
    default_meta = ((), ())
    decompress_impl(encoded, default_meta)
end


struct Constructor{A} end
function (::Constructor{A})(args...) where {A}
    A(args...)
end

function compress_impl!(a::QuoteNode)
    meta, sub = compress_impl!(a.value)
    meta = SimpleMeta(meta.complexity)
    encoded = Call(Constructor{QuoteNode}(), tuple(sub))
    if meta.complexity < CacheComplexityThres
        encoded = _get_id!(CallPool, CallIndex, encoded, FLAGS.Call)
    end
    return SimpleMeta(meta), encoded
end

function compress_impl!(a::GlobalRef)
    _, mod_encoded = compress_impl!(a.mod)
    _, name_encoded = compress_impl!(a.name)
    meta = SimpleMeta(1)
    encoded = Call(Constructor{GlobalRef}(), tuple(mod_encoded, name_encoded))
    return meta, encoded
end

function may_cache_call(meta::Union{ExprMeta,SimpleMeta}, call::Call)
    if meta.complexity < CacheComplexityThres
        SimpleMeta(meta), _get_id!(CallPool, CallIndex, call, FLAGS.Call)
    else
        SimpleMeta(meta), call
    end
end
