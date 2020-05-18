using Documenter, Soss

DocMeta.setdocmeta!(Soss, :DocTestSetup, 
    quote
        using Soss
        import Random
        Random.seed!(3)
    end; recursive=true)

makedocs(;
    modules=[Soss],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/cscherrer/Soss.jl/blob/{commit}{path}#L{line}",
    sitename="Soss.jl",
    authors="Chad Scherrer",
    assets=String[],
)

deploydocs(;
    repo="github.com/cscherrer/Soss.jl",
    push_preview=true
)
