Soss needs the body of a model to be of the form
```julia
begin
    line_1
    ⋮
    line_n
end
```
Each line is syntactically translated into a `Statement`. This is an abstract type, with subtypes `Assign` and `Sample`. For example,
```julia
x ~ Normal(μ,σ)
```
becomes
```julia
Sample(:x, :(Normal(μ,σ)))
```
Next, all of the `Sample`s are brought together to build a named tuple mapping each `Symbol` to its `Expr`. This becomes the `dists` field for a `Model`.

Because all of this is entirely syntactic, translating into another form only helps when its done on the right side of `~` or `=`. Otherwise we need another way to represent this information.
