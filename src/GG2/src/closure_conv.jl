using JuliaVariables
using MacroTools: @q
using MLStyle
include("ngg/ngg.jl")
include("utils.jl")
include("closure.jl")
using .NGG
include("func_arg_decs.jl")

"""`ex` should be a scoped expression
"""
function closure_conv(top::Any, ex::Any)
    function conv(ex::Expr)
        @when Expr(:scoped, scope, inner) = ex begin
            block = Any[]
            for var in scope.bounds
                if var.is_mutable && var.is_shared
                    name = var.name
                    # if var.name in scope.bound_inits
                    #     push!(block, :($name = Core.Box($name)))
                    # else
                    #     push!(block, :($name = Core.Box()))
                    # end
                end
            end
            push!(block, conv(inner))
            Expr(:block, block...)
        @when Expr(:function, head, inner && Expr(:scoped, scope, _)) = ex

            freenames = Symbol[f.name for f in scope.freevars]
            # If the evaluation module is a symbol and not in arguments
            if top isa Symbol && all(scope.bounds) do e
                e.name !== top
            end
                push!(freenames, top)
            end

            head = conv(head)
            fh = func_header(head)
            lambda_n = Symbol(:function)
            name = fh.name === unset ? lambda_n : fh.name
            fh = @with fh.args = FuncArg[map(func_arg, freenames)..., fh.args...]

            if fh.fresh !== unset || fh.ret !== unset
                error("GG doesn't support type parameters or return type annotations.")
            end

            args = of_args(fh.args)
            kwargs = of_args(fh.kwargs)
            inner = conv(inner)

            fn = mkngg(Symbol(name), args, kwargs, inner)
            if !isempty(freenames)
                closure_vars = Expr(:tuple, freenames...)
                fn = quote
                    let freevars = $closure_vars
                        $Closure{$fn,Base.typeof(freevars)}(freevars)
                    end
                end
            end

            if name !== lambda_n
                fn = Expr(:block, :($(fh.name) = $fn))
            end
            fn
        @when Expr(:let, var::Var, body) = ex
            Expr(:let, var.name, conv(body))
            # Soss#331: even if a uninitialized let-bound variable is free, 
            # we don't convert it to `$var.contents`
        @when Expr(hd, args...) = ex
            Expr(hd, map(conv, args)...)
        end
    end

    function conv(s::Var)
        name = s.name
        s.is_global && return :($top.$name)
        # s.is_mutable && s.is_shared && return begin
        #     :($name.contents)
        # end
        name
    end
    conv(s) = s

    conv(ex.args[2])
end

function _get_body(::RuntimeFn{Args,Kwargs,Body}) where {Args,Kwargs,Body}
    Body
end

function _get_body(ex)
    error(ex)
end

struct UnderGlobal
    mod::Any
    ex::Any
end

macro under_global(m, ex)
    esc(:($UnderGlobal($m, $ex)))
end

function gg(compmod::Module, runmod::Any, source::Union{Nothing,LineNumberNode}, ex)
    (head, body) = @match ex begin
        Expr(:(=), head, body) => (head, body)
        Expr(:function, head, body) => (head, body)
        Expr(:->, head, body) => (head, body)
        _ => error("Malformed generated function at $source.")
    end

    fh = func_header(head)
    locals = Any[]
    if fh.args !== unset
        for arg in fh.args
            push!(locals, arg.name)
        end
    end
    if fh.kwargs !== unset
        for arg in fh.kwargs
            push!(locals, arg.name)
        end
    end
    if fh.fresh !== unset
        for name in map(extract_tvar, fh.fresh)
            push!(locals, name)
        end
    end
    if fh.name !== unset
        push!(locals, fh.name)
    end

    pseudo_head = Expr(:tuple, locals...)

    genbody = @q begin
        $source
        let body = $body
            if body isa $UnderGlobal
                ast = Base.macroexpand($compmod, body.ex)
                fake_ast = Base.Expr(:function, $(QuoteNode(pseudo_head)), ast)
                fake_ast = $simplify_ex(fake_ast)
                fake_ast = $solve!(fake_ast)
                fake_fn = $closure_conv(body.mod, fake_ast)
                $from_type($_get_body(fake_fn))
            else
                ast = Base.macroexpand($compmod, body)
                fake_ast = Base.Expr(:function, $(QuoteNode(pseudo_head)), ast)
                fake_ast = $simplify_ex(fake_ast)
                fake_ast = $solve!(fake_ast)
                fake_fn = $closure_conv($(QuoteNode(runmod)), fake_ast)
                $from_type($_get_body(fake_fn))
            end
        end
    end

    generator = Expr(:function, head, genbody)
    Expr(:macrocall, Symbol("@generated"), source, generator)
end

macro gg(ex)
    ex = gg(__module__, __module__, __source__, ex)
    esc(ex)
end
