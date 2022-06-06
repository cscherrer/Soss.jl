# GeneralizedGenerated

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaStaging.github.io/GeneralizedGenerated.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaStaging.github.io/GeneralizedGenerated.jl/dev)
[![Build Status](https://travis-ci.com/JuliaStaging/GeneralizedGenerated.jl.svg?branch=master)](https://travis-ci.com/JuliaStaging/GeneralizedGenerated.jl)
[![Codecov](https://codecov.io/gh/JuliaStaging/GeneralizedGenerated.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaStaging/GeneralizedGenerated.jl)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3596233.svg)](https://doi.org/10.5281/zenodo.3596233)

GeneralizedGenerated enables the generalized generated functions. Specifically, **it supports closure constructions in generated functions**.

Besides, some utility stuffs relevant to GeneralizedGenerated's implementation are exported,
which **allows you to keep `eval` and `invokelastest`** away from Julia
metaprogramming.

## Notes about Usage:

`GeneralizedGenerated.jl` has issues about latency and extensive memory consumptions, and is sometimes likely to trigger segfault bugs when generated functions get enormous([#45](https://github.com/JuliaStaging/GeneralizedGenerated.jl/issues/45), [#59](https://github.com/JuliaStaging/GeneralizedGenerated.jl/issues/59)). This suggests that you should avoid your expressions from being too large.

In terms of **use cases where no closure is needed**, you'd better use [RuntimeGeneratedFunctions.jl](https://github.com/SciML/RuntimeGeneratedFunctions.jl), which has better scalability than `GeneralizedGenerated.jl`.

P.S:
- You should also re-check if closures are really necessary in your code.
- If you use `mk_function` or similar stuffs in a non-global loop, but only call those generated functions once, you might re-think if your design can be refined to avoid this.

## Background: World Age Problem

See an explanation [here](https://discourse.julialang.org/t/world-age-problem-explanation/9714/4).

```julia
julia> module WorldAgeProblemRaisedHere!
           do_this!(one_ary_fn_ast::Expr, arg) = begin
               eval(one_ary_fn_ast)(arg)
           end
           res = do_this!(:(x -> x + 1), 2)
           @info res
       end
ERROR: MethodError: no method matching (::getfield(Main.WorldAgeProblemRaisedHere!, Symbol("##1#2")))(::Int64)
The applicable method may be too new: running in world age 26095, while current world is 26096.

julia> module WorldAgeProblemSolvedHere!
           
           do_this!(one_ary_fn_ast::Expr, arg) = begin
               runtime_eval(one_ary_fn_ast)(arg)
           end
           res = do_this!(:(x -> x + 1), 2)
           @info res
       end
[ Info: 3
Main.WorldAgeProblemSolvedHere!
```

## Support Closures in Generated Functions

```julia


@gg function f(x)
    quote
        a -> x + a
    end
end

f(1)(2) # => 3

@gg function h(x, c)
    quote
        d = x + 10
        function g(x, y=c)
            x + y + d
        end
    end
end

h(1, 2)(1) # => 14
```

Note there're some restrictions to the generalized generated functions yet:

- Multiple dispatch is not allowed, and `f(x) = ...` is equivalent to `f = x -> ...`. This will never gets supported for it needs a thorough implementation of multiple dispatch in GG.
- Comprehensions for generated functions are not implemented yet. It won't cost a long time for being supported.

The evaluation module can be specified in this way:

```julia
julia> module S
           run(y) = y + 1
       end
Main.S

julia> @gg g(m::Module, y) = @under_global :m :(run(y));
# the global variable `run` is from the local variable `m`
# <=>
# @gg g(m::Module, y) = :($(:m).run(y));

julia> g(S, 1)
2
```

Of course you can use structures to imitate modules:

```julia
julia> struct S
           run :: Function
       end
Main.S

julia> @gg function g(m::S, y)
            @under_global :m quote
                run(y)
            end
       end;
# <=>
# @gg function g(m::S, y)
#    :($(:m).run(y))
# end;

julia> g(S(x -> x + 1), 1)
2

julia> const pseudo_module = S(x -> x + 1);
julia> @gg function g(y)
            @under_global pseudo_module quote
                run(y)
            end
       end
# <=>
# @gg function g(y)
#    :($(pseudo_module).run(y))
# end
julia> g(1)
2
```

julia> @generated function g()
    Module = Main
    mk_expr(Module,  :( (x -> x)(1)))
end

## No `eval`/`invokelatest`!

```julia
# do something almost equivalent to `eval`
# without introducing the world age problem!

f = mk_function(:((x, y) -> x + y))
f(1, 2)
# => 3

f = mk_function([:x, :y]#= args =#, []#= kwargs =#, :(x + y))
f(1, 2)
# => 3


module GoodGame
    xxx = 10
end
# Specify global module
f = mk_function(GoodGame, :(function () xxx end))
f()
# => 10
```

The function created by `mk_function` always has the signature `f(args…; kwargs…) = ...` if you need to use the function in a context where it will be passed multiple arguments, use the following pattern

```julia
f = mk_function(:((x, y) -> x + y))

function F(g, pairs)
  map(pairs) do (x,y)
    g(x,y)
  end
end

pairs = zip(1:10,2:11)
F((x,y)->f(x,y), pairs)
#=
=>
10-element Array{Int64,1}:
  3
  5
  7
  9
 11
 13
 15
 17
 19
 21
=#
```

Tips
==============

Note, `mk_function` just accepts a function-like AST, to eval more kinds of
ASTs, use `runtime_eval`:

```julia
a = 0
runtime_eval(:(a + 1)) == 1 # true

module GoodGameOnceAgain
    a = 2
end
runtime_eval(GoodGameOnceAgain, :(a + 3)) == 5
```

# Known Bugs

1. Type annotations.

    Type annotations for cell variables (variables shared to any inner functions of the  current scope) do not work. You might consider changing your generated code from

    ```julia
    a :: t = b
    # when 'a' is  cell,
    # the closure-converted code 'a.contents :: t = b' fails due to the Julia syntax
    ```

    to

    ```julia
    a = b :: t
    ```

2. Precompilation

    GG is designed for purely runtime generated functions, and currently has difficulties in precompiling a GG function.

    When developing a package, please do not define a GG function in the top level!
