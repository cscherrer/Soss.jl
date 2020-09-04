using Soss
using Documenter

import Literate

include(joinpath(dirname(dirname(@__FILE__)), "test", "examples-list.jl"))

pages_before_examples = [
    "Home" => "index.md",
    "Installing Soss" => "installing-soss.md",
]
pages_examples = ["Examples" => ["$(example[1])" => "example-$(example[2]).md" for example in EXAMPLES]]
pages_after_examples = [
    "Soss API" => "api.md",
    "SossMLJ.jl" => "sossmlj.md",
    "Internals" => "internals.md",
    "Miscellaneous" => "misc.md",
    "To-Do List" => "to-do-list.md",
]
pages = vcat(
    pages_before_examples,
    pages_examples,
    pages_after_examples,
)

# Use Literate.jl to generate Markdown files for each of the examples
for example in EXAMPLES
    input_file = joinpath(EXAMPLESROOT, "example-$(example[2]).jl")
    Literate.markdown(input_file, DOCSOURCE)
end

DocMeta.setdocmeta!(Soss, :DocTestSetup,
    quote
        using Soss
        import Random
        Random.seed!(3)
    end; recursive=true)

makedocs(;
    modules=[Soss],
    format=Documenter.HTML(),
    pages=pages,
    repo="https://github.com/cscherrer/Soss.jl/blob/{commit}{path}#L{line}",
    sitename="Soss.jl",
    authors="Chad Scherrer",
    strict=true,
)

deploydocs(;
    repo="github.com/cscherrer/Soss.jl",
)
