using Documenter, GeneralizedGenerated

makedocs(;
    modules=[GeneralizedGenerated],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/thautwarm/GeneralizedGenerated.jl/blob/{commit}{path}#L{line}",
    sitename="GeneralizedGenerated.jl",
    authors="thautwarm",
    assets=String[],
)

deploydocs(;
    repo="github.com/thautwarm/GeneralizedGenerated.jl",
)
