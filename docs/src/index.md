# `Model`s and `JointDistribution`s

A `Model` in Soss

# Model Combinators



# Building Inference Algorithms

## Inference Primitives

At its core, Soss is about source code generation. Instances of this are referred to as *inference primitives*, or simply "primitives". As a general rule, **new primitives are rarely needed**. A wide variety of inference algorithms can be built using what's provided. 

To easily find all available inference primitives, enter `Soss.source<TAB>` at a REPL. Currently this returns this result:

```julia
julia> Soss.source
sourceLogpdf         sourceRand            sourceXform
sourceParticles      sourceWeightedSample
```

The general pattern is that a primitive `sourceFoo` specifies how code is generated for a function `foo`. 

For more details, see the *Internals* section.

## Inference Functions

## Chain Combinators



## 

## 

# Internals

## `Model`s



```julia
struct Model{A,B} <: AbstractModel{A,B}
    args  :: Vector{Symbol}
    vals  :: NamedTuple
    dists :: NamedTuple
    retn  :: Union{Nothing, Symbol, Expr}
end
```



```julia
function sourceWeightedSample(_data)
    function(_m::Model)

        _datakeys = getntkeys(_data)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        function proc(_m, st :: Sample)
            st.x ∈ _datakeys && return :(_ℓ += logpdf($(st.rhs), $(st.x)))
            return :($(st.x) = rand($(st.rhs)))
        end

        vals = map(x -> Expr(:(=), x,x),variables(_m)) 

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            
            return (_ℓ, $(Expr(:tuple, vals...)))
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end

```



# Internals

## `Model`

##  