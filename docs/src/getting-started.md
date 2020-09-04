```@meta
CurrentModule = Soss
```

# Getting Started

Soss is an officially registered package, so to add it to your project you can type
````julia
julia> import Pkg; Pkg.add("Soss")
````

within the julia REPL and you are ready for `using Soss`. If it fails to precompile, it could be due to one of the following:

1. You have gotten an old version due to compatibility restrictions with your current environment.
Should that happen, create a new folder for your Soss project, launch a julia session within, type
````julia
julia> import Pkg; Pkg.activate(pwd())
````
and start again. More information on julia projects [here](https://julialang.github.io/Pkg.jl/stable/environments/#Creating-your-own-projects-1).
2. You have set up PyCall to use a python distribution provided by yourself. If that is the case, make sure to install the missing python dependencies, as listed in the precompilation error. More information on PyCall's python version [here](https://github.com/JuliaPy/PyCall.jl#specifying-the-python-version).
