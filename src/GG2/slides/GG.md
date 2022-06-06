
# Background

## Generated Functions in Julia

Julia can only create functions statically. Accurately, apart from using the `@generated` macro(generated functions), we can create functions
- literally for each function, or
- by calling macros

These 2 means only work when building a module, however
once a module got built, no way to create a new function
in current [world age](https://discourse.julialang.org/t/world-age-problem-explanation/9714).

However, there're still cases that we have to generate functions
according to runtime data, hence Julia has provided a solution called
the [generated function](https://docs.julialang.org/en/v1/manual/metaprogramming/#Generated-functions-1).

The name of the generated function doesn't suggest its powerful. I used to introduce this to
fans of DrRacket, they immediately responsed, "generating functions is trivial, exactly the most common sight in LISP idioms". Though it was not their fault, they just tried to understand it literally, but I
do feel like to laugh them at the street :-)

In dynamic languages, when we generate functions from runtime data, we must have following steps:

- invoke the generator with runtime data as its parameters, and bind the expression to a symbol to represent the generated function.
  The generator might build an AST(abstract syntax tree) which represents the generated
  function, and compile/execute it to a runtime object.

- calling the generated function at each expected callsite.


However, generated functions in Julia are more convenient, we only need to return the AST of the generated function, and compiler will do the remaining tasks for us.

**This, Julia's generated function, becomes extremely useful when we need a polymorphic generated function**.

Polymorphisms can be achieved by **generics** or **templates**. The former one, will use the same code
to process parameters of various types, while the latter provides specialized code for each group
of the parameter types. Usually, the former is more dynamic, slow(for requiring runtime coercions) and limited(might disallow polymorphisms for specific types, like value types in Java), while the latter is
static, fast, flexible.

Julia's generated function achieves polymorphism via templates, and it can take advantage of
static information to decide which specialized codes will be used in the callsite. Thus, we simply
achieve the free-lunch polymorphic generated functions, **without manually managing the construction of each specialized function, or choosing a mechanism to decide which specialized function to use in the callsite**.

Julia's generated function is indeed a miracle, personally I'd call it *Zero-Cost-Staging*.

## The Restrictions of Generated Function

The generated functions perform code generation based on the types of parameters.

```julia
function add(x::T, y::T)
    if T <: Number
        :(x + y)
    else if T <: AbstractString
        :(x * y) # '*' is string concatenation in Julia
    else
        throw("fatal")
    end
end
```

### "Typeability"? What Can Functions Be Generated From?

The first restriction is, we can only generate functions based on typeable data.

**Typeable** here is not an official term, I use this to indicate the data
that can be held in the type parameters, you can roughly treat it as **immutable**, but
the scope of the former is smaller than the latter.

However, although Julia is a dynamic language,
a Julia type should be immutable datum. Which means
we cannot do code generation based on things like
`String`s(until Julia 1.2.x), mutable states, etc.

However, this is not a challenge at all. In terms of
every domain specific problem, **we can demonstrate a
form to express all non-typeable components**. Since that,
we can easily transform a non-typeable data to typeable
representations, and the reverse is also true.

Fortunately, this problem got solved when working with Chad for his
[Soss.jl](https://github.com/cscherrer/Soss.jl). We wanted to avoid
evaluating ASTs in runtime and using `invokelastest`, and we then
achieved it by holding something equivalent to AST of the expected
generated function in type parameters.

For instance, if we want to make Julia's AST types typeable, there's
a solution,

```julia
abstract type TypeLevel end
struct TLCons{Hd, Tl} <: TypeLevel end
struct TLNil <: TypeLevel end
struct TLVal{Val} <: TypeLevel end
struct TLSExp{Fn, Args} <: TypeLevel end

function typelevellist(l)
    foldr(l, init=TLNil) do each, prev
        TLCons{each, prev}
    end
end

function expr2typelevel(x)::Type{TypeLevel}
    # omit
end

function interpret(t::Type{TypeLevel})
    # omit
end
```

and you can check the whole implementation [here](https://github.com/cscherrer/Soss.jl/blob/4733a8e5083deaffbc893ab7e6bca7b122eff54a/src/utils.jl#L455-L514).

### Purity? What Can Generated Codes Be?

The generated codes cannot be impure(with side effects), but the compiler is really conservative.

Say, we cannot use loal functions...

```julia

julia> @generated f() = :(() -> 1)
f (generic function with 1 method)

julia> f()
ERROR: generated function body is not pure. this likely means it contains a closure or comprehension.
Stacktrace:
 [1] top-level scope at none:0
```

Currently, the generate code cannot be a function, nor a generator, which is clarified in the document of
Julia v1.1.1.

> Due to an implementation limitation, this also means that they currently cannot define a closure or generator.

So this is still unresolved problem, and exactly is what we will mainly discuss in this article.


# The Runtime Function Generation

## Closure Conversions

In the sense of intuition, when we want to do what a specific function will do,
we're considering constructing this function. However, it's not the only manner.

Firstly let me simply introduce the closure conversions,

Given following codes,
```julia
function f(x, y)
    function g(z)
        x + z
    end
    g
end
```

We can find there's a free variable `x` in the inner function `g`. To eliminate
free variables, if we presume
- all free variables are readonly and,
- the closure function isn't recursive,
we can introduce a structure(`Closure`) to represent a closure:

```julia
struct Closure{F, Free}
    frees :: Free
end

function global_g((x, ), z)
    x + z
end

function (closure::Closure{F, X})(args...; kwargs...) where {F, X}
    F(closure.frees, args...; kwargs...)
end

function f(x, y)
   Closure{global_g, typeof(x)}(x)
end
```

The automation of above transformations is very simple to implement,
if you already have tools to analyse the scopes.

Say, we can have such a function called `scoping`,

```julia
scoping(
    :(function f(x, y)
        function g(z)
            x + z
        end
    end)
) == Expr(
    :scope,
    (:x, :y, :g), # locals/bounds
    (),           # free variables
    (),           # globals
    inner_expr
)
```
And inside the `inner_expr`, for function `g`, we
will have a scope expression:

```julia
Expr(
    :scope,
    (:z, ), # bounds
    (:x, ), # free variable
    (),     # globals
    inner_expr2
)
```

Now, we point out that every scope expression can
produce one or more global function pointers by following
procedures:

- if a scope expression contains no free variables, do nothing,
- otherwise, for expression `Expr(:scope, bounds, frees, globs, expr)`,
  we generate a closure structure with `frees`:

```julia
struct Closure{F, Free}
    frees :: Free
end

function (closure::Closure{F, X})(args...; kwargs...) where {F, X}
    F(closure.frees, args...; kwargs...)
end

function split_args_kwargs(args)
    i_ = findfirst(x -> Meta.isexpr(x, :parameter), args)
    i = i_ === nothing ? 0 : i_
    (args[i+1:end], args[1:i])
end

# impl for closure conversion
function mk_closure_static(expr, toplevel::Vector{Expr})
    rec(expr) = mk_closure_static(expr, toplevel)
    @match expr begin
        # main logic
        Expr(:scope, _, frees, _, inner_expr) =>
            let closure_arg = :($(frees...), ),
                name = "",
                args   = Symbol[]

                @match inner_expr begin
                    Expr(:function, :($name($(args...), )), body)            ||
                    # (a, b, c, ...) -> body / function (a, b, c, ...) body end
                    Expr(:-> || :function, Expr(:tuple, args...), body)      ||
                    # a -> body
                    Expr(:-> || :function, a::Symbol, body) && Do(args=[a])  =>
                        let glob_name   = gensym(name),
                            (args, kwargs) = split_args_kwargs(args),
                            body   = rec(body)

                            (fn_expr, ret) = if isempty(frees)
                                fn_expr = Expr(
                                    :function,
                                    :($glob_name($(args...); $(kwargs...))),
                                    body
                                )
                                (fn_expr, :glob_name)
                            else
                                fn_expr = Expr(
                                    :function,
                                    :($glob_name($closure_arg, $(args...); $(kwargs...))),
                                    body
                                )
                                ret = :(let frees = $closure_arg
                                    $Closure{$glob_name, typeof(frees)}(frees)
                                end)
                                (fn_expr, ret)
                            end

                            push!(toplevel, fn_expr)

                            if name == "" # anonymous function
                                ret
                            else
                                :($name = $glob_name)
                            end
                        end

                    _ => throw("unsupported closures")
                end
            end
        Expr(hd, tl...) => Expr(hd, map(rec, tl)...)
        a               => a
    end
end

function closure_conv(block)
    defs = Expr[]
    push!(defs, mk_closure_static(scoping(block), defs))
    Expr(:block, defs...)
end


macro closure_conv(block)
    closure_conv(block) |> esc
end
```

To support mutable free variables, we should capture the structure
where free variables are stored, it's a bit internal.

To support self/mutual recursions, we can make `Closure` mutable,
and make the free variables wrapped in `Ref`:

```julia
function ...
    function g(x)
        do_some(g, x)
    end
end
```

Above codes can be statically transformed to

```julia
function glob_g((refg,), x)
    g = refg.x
    do_some(g, x)
end

function ...
    let refg = Ref{Closure}(),
        frees = (refg, ),
        closure = Closure{glob_x, typeof(frees)}(frees)
        refg.x = closure
        closure
    end
end
```

Until now, we don't have such a `scoping` function in the community,
and it's somewhat a little heavy assignment.

We're now looking for people to implement this together.

## Generating Functions From Typeable Data In Runtime

In this sub-section, we'll introduce a method equivalently powerful as `eval`
but without a world age problem.

Our main goal is to allow closures in generated functions,
which is performing runtime code generation.

Above techniques(closure conversions) are purely static, thus useless to our goal.

However, we propose a type to achieve generating non-closure functions
in runtime:

```julia
struct RuntimeFn{Args, Kwargs, Body} end
```

where both `Args` and `Kwargs` are typeable representations of
the ASTs that represent arguments,
and `Body` is a typeable representation of Julia AST.

At here, we'll use the `TypeLevel` mentioned above to represent `Body`.

Then comes one of key ideas:

```julia
using Parameters
@generated function (::RuntimeFn{Args, Kwargs, Body})(args...; kwargs...) where {Args, Kwargs, Body}
    args_ = interpret(Args)
    kwargs_ = interpret(Kwargs)
    body = interpret(Body)
    quote
        $args_ = args
        @unpack $kwargs_ = kwargs
        $body
    end
end

args = expr2typelevel(:(x, y))
kwargs = expr2typelevel(:())
body = expr2typelevel(:(x + y))
fn = RuntimeFn{args, kwargs, body}()

fn(1, 2) # => 3
```

Here comes the runtime generations of functions!

From now on, no need for `eval` and `invokelatest`!

## Closure Conversions For Generated Functions

Now things have got clarified! Since we can already generate non-closure functions
from arbitrary typeable data in runtime, we can then perform closure conversions
based on runtime generated non-closure functions, instead of generating static top
level(global scope) functions.


Following implementation will support closures in generated functions,
when no default arguments used.

```julia
function closure_conv_staged(expr)
    rec = closure_conv_staged
    @match expr begin
        # main logic
        Expr(:scope, _, frees, _, inner_expr) =>
            let closure_arg = Expr(:tuple, frees...),
                name = "",
                args   = Symbol[]
                @match inner_expr begin
                    Expr(:function, :($name($(args...), )), body)            ||
                    # (a, b, c, ...) -> body / function (a, b, c, ...) body end
                    Expr(:-> || :function, Expr(:tuple, args...), body)      ||
                    # a -> body
                    Expr(:-> || :function, a::Symbol, body) && Do(args=[a])  =>
                        let (args, kwargs) = split_args_kwargs(args),
                            body   = rec(body),
                            kwargs = map(x -> x.args[1], kwargs)
                            Kwargs = expr2typelevel(Expr(:tuple, kwargs...))
                            Body   = expr2typelevel(body)
                            if isempty(frees)
                                Args = expr2typelevel(Expr(:tuple, args...))
                                RuntimeFn{Args, Kwargs, Body}()
                            else
                                Args = expr2typelevel(Expr(:tuple, closure_arg, args...))
                                non_closure_fn = RuntimeFn{Args, Kwargs, Body}()
                                ret = :(let frees = $closure_arg
                                    $Closure{$non_closure_fn, typeof(frees)}(frees)
                                end)
                                if name == "" # anonymous function
                                    ret
                                else
                                    :($name = $ret)
                                end
                            end
                        end
                    _ => throw("unsupported closures")
                end
            end
        Expr(hd, tl...) => Expr(hd, map(rec, tl)...)
        a               => a
    end
end
```

The use is simple:

```julia
function gg(x)
    closure_conv_staged(scoping(x))
end

@generated function f(x)
    quote
        () -> x + 1
    end |> gg
end
```

Currently, what we only lack of is the implementation of `scoping`, and
making it is expected to cost a few days. However, for prototyping, we
can simply the cases, by peforming explicit capturing.

In our prototype, we use following notations to express a closure function,
which looks pretty similar to those in C++:

```julia
# x, y is free variables
[x, y](a) ->  x*(a + y)
[](a) -> a
```

In our test cases, you can find out codes that look like

```julia
@generated function f(x)
    quote
        [x](a) ->  x + a
    end |> gg
end
@test f(1)(2) == 3
```