```@meta
CurrentModule = Soss
```

# To-Do List

We need a way to "lift" a "`Distribution`" (without parameters, so really a family) to a `DAGModel`, or one with parameters to a `ConditionalModel`

DAGModels are "function-like", so a `ConditionalModel` should be sometimes usable as a value. `m1(m2(args))` should work.

This also means `m1 ∘ m2` should be fine

Since inference primitives are specialized for the type of data, we can include methods for `Union{Missing, T}` data. PyMC3 has something like this, but for us it will be better since we know at compile time whether any data are missing.

There's a `return` available in case you want a result other than a `NamedTuple`, but it's a little fiddly still. I think whether the `return` is respected or ignored should depend on the inference primitive. And some will also modify it, similar to how a state monad works. Likelihood weighting is an example of this.

Rather than having lots of functions for inference, anything that's not a primitive should (I think for now at least) be a method of... let's call it `sample`. This should always return an iterator, so we can combine results after the fact using tools like `IterTools`, `ResumableFunctions`, and `Transducers`.

This situation just described is for generating a sequence of samples from a single distribution. But we may also have models with a sequence of distributions, either observed or sampled, or a mix. This can be something like Haskell's `iterateM`, though we need to think carefully about the specifics.

We already have a way to `merge` models, we should look into intersection as well.

We need ways to interact with Turing and Gen. Some ideas:

- Turn a Soss model into an "outside" (Turing or Gen) model
- Embed outside models as a black box in a Soss model, using their methods for inference

We are working on the
[SossMLJ](https://github.com/cscherrer/SossMLJ.jl)
package, which will provide an interface between Soss and the
[MLJ](https://github.com/alan-turing-institute/MLJ.jl)
machine learning framework.
