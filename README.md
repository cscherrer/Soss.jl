Soss is a library for _probabilistic programming_

Let's jump right in with a simple model:

```julia
m = @model σ begin
    μ ~ Normal(0,1)
    x ~ Normal(μ,σ) |> iid(3)
end;
```

`iid` here means [independent and identically distributed](https://en.wikipedia.org/wiki/Independent_and_identically_distributed_random_variables). This really just means `x` will consist of 3 samples from the same `Normal(μ,σ)` distribution.

If we call this with `rand`, it works as if we had defined a `Distribution`:

```julia
julia> rand(m(σ=1))
(σ = 1, μ = -0.5501310309951254, x = [-1.4490947813119675, -0.7321340792184637, -0.6933769500276799])
```

And just like with `Distribution`s, we can go in the other direction:

```julia
julia> logpdf(m(σ=1), (μ=0, x=[-1,0,1]))
-4.675754132818691
```

## What's Really Happening Here?

Under the hood, `rand` and `logpdf` specify different ways of "running" the model.

 `rand`  turns each `v ~ dist` into `v = rand(dist)`, finally outputting the `NamedTuple` of all values it has seen.

`logpdf` steps through the same program, but instead accumulates a log-density. It begins by initializing `_ℓ = 0.0`. Then at each step, it turns `v ~ dist` into `_ℓ += logpdf(dist, v)`, before finally returning `_ℓ`.

Note that I said "turns into" instead of "interprets". Soss uses [`GG.jl`](https://github.com/thautwarm/GG.jl) to generate specialized code for a given model, inference primitive (like `rand` and `logpdf`), and type of data. 

This idea can be used in much more complex ways. `weightedSample` is a sort of hybrid between `rand` and `logpdf`. For data that are provided, it increments a `_ℓ` using `logpdf`. Unknown values are sampled using `rand`.

```julia
julia> weightedSample(m(σ=1), (μ=0.0,))
(-0.9189385332046728, (σ = 1, μ = 0.0, x = [1.4022646662147151, 0.5619286714811451, 1.0666556455847045]))

julia> weightedSample(m(σ=1), (x=[-1,0,1],))
(-3.7839836623738043, (σ = 1, μ = 0.13458098617508069, x = [-1, 0, 1]))
```

Again, there's no runtime check needed for this. Each of these is compiled the first time it is called, so future calls are very fast. Functions like this are great to use in tight loops.

## Inference



```julia
julia> nuts(m(σ=1),(x=[-1,0,1],)) |> particles
(μ = -0.00502 ± 0.47,)
```

## To Do

We need a way to "lift" a `Distribution` (without parameters) to a `Model`, or one with parameters to a `BoundModel`

Should we rename `BoundModel`? It's really a generative process.

Models are "function-like", so a `BoundModel` should be sometimes usable as a value. `m1(m2(args))` should work.

This also means `m1 ∘ m2` should be fine

We need some terminology. I think maybe things that use `@gg` should be "inference primitives". We have some (and will have many more) inference methods that don't call this directly

Since inference primitives are specialized for the type of data, we can include methods for `Union{Missing, T}` data. PyMC3 has something like this, but for us it will be better since we know at compile time whether any data are missing.

There's a `return` available in case you want a result other than a `NamedTuple`, but it's a little fiddly still. I think whether the `return` is respected or ignored should depend on the inference primitive. And some will also modify it, similar to how a state monad works. Likelihood weighting is an example of this.

Rather than having lots of functions for inference, anything that's not a primitive should (I think for now at least) be a method of... let's call it `sample`. This should always return an iterator, so we can combine results after the fact using tools like `IterTools`, `ResumableFunctions`, and `Transducers`.

This situation just described is for generating a sequence of samples from a single distribution. But we may also have models with a sequence of distributions, either observed or sampled, or a mix. This can be something like Haskell's `iterateM`, though we need to think carefully about the specifics.

A model is also like a poset (via the variable dependency DAG). Slicing could be very useful, as `m[:a,:b]`

We already have a way to `merge` models, we should look into intersection as well.

We need ways to interact with Turing and Gen. Some ideas:

- Turn a Soss model into an "outside" (Turing or Gen) model
- Embed outside models as a black box in a Soss model, using their methods for inference


