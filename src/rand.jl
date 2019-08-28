using GG

nt = NamedTuple{(),Tuple{}}

export rand

rand(m) = _rand(m,NamedTuple(),NamedTuple())

function loadvals(argstype, datatype)
    args = getntkeys(argstype)
    @info args
    data = getntkeys(datatype)
    loader = @q begin
    end

    for k in args
        push!(loader.args, :($k = _args.$k))
    end
    for k in data
        push!(loader.args, :($k = _data.$k))
    end

    src -> (@q begin
        $loader
        $src
    end) |> flatten
end

function loadvals(argstype, datatype, parstype)
    args = getntkeys(argstype)
    @info args
    data = getntkeys(datatype)
    pars = getntkeys(parstype)

    loader = @q begin

    end

    for k in args
        push!(loader.args, :($k = _args.$k))
    end
    for k in data
        push!(loader.args, :($k = _data.$k))
    end

    for k in pars
        push!(loader.args, :($k = _pars.$k))
    end

    src -> (@q begin
        $loader
        $src
    end) |> flatten
end


getntkeys(::NamedTuple{A,B}) where {A,B} = A 
getntkeys(::Type{NamedTuple{A,B}}) where {A,B} = A 

@generated function _rand(_m::Model{A,B,D}, _args::A, _data::D) where {A,B,D} 
    s = type2model(_m) |> sourceRand |> loadvals(_args, _data)
    @info s
    s
end

export sourceRand
function sourceRand(m::Model{A,B,D}) where {A,B,D}
    _m = canonical(m)
    proc(_m, st::Assign)  = :($(st.x) = $(st.rhs))
    proc(_m, st::Sample)  = :($(st.x) = rand($(st.rhs)))
    proc(_m, st::Observe) = :($(st.x) = rand($(st.rhs)))
    proc(_m, st::Return)  = :(return $(st.rhs))
    proc(_m, st::LineNumber) = nothing

    stochExpr = begin
        vals = map(x -> Expr(:(=), x,x),variables(_m)) 
        Expr(:tuple, vals...)
    end

    wrap(kernel) = @q begin
        $kernel
        $stochExpr
    end
    
    buildSource(_m, proc, wrap) |> flatten
end