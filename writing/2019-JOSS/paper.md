---
title: 'Soss: Code Generation for Probabilistic Programming in Julia'
tags:
  - Julia language
  - probabilistic programming
  - Bayesian statistics
  - code generation
  - metaprogramming
authors:
  - name: Chad Scherrer
    orcid: 0000-0002-1490-0304
    affiliation: 1 # "1, 2" # (Multiple affiliations must be quoted)
  - name: Taine Zhao
    affiliation: 2
affiliations:
 - name: RelationalAI
   index: 1
 - name: Department of Computer Science, University of Tsukuba
   index: 2
date: 7 Dec 2019
bibliography: paper.bib
---

# Summary

Probabilistic programming is a rapidly growing field, but is still far from mainstream use, due at least in part to a common diconnect between performance and ease of use. Soss aims to achieve the best of both worlds, by offering a simple mathematical syntax and specialized code generation behind the scenes.

For example, here's a simple Gaussian model:

```julia
m = @model sigma,N begin
    mu ~ Cauchy(0,1)
    y ~ For(N) do j
            Normal(mu,sigma)
        end
    end
```

Given this, a user can do things like

- Specify the `sigma` and `N` arguments, and "forward sample" from the model (`rand`)
- Compute the log-density (`logpdf`)
- Call to external inference libraries that benefit from these or other inference primitives
- Transform the model to yield new models, for example using a known value for `mu` or computing the Markov blanket at a node
- Find the symbolic log-density, using John Verzani's [`SymPy.jl`](https://github.com/JuliaPy/SymPy.jl) bindings to SymPy [@10.7717/peerj-cs.103]
- Use the result of symbolic simplification to generated optimized code, often with significant performance benefits

At the time of this writing, Soss can connect (through the main library or optional add-ons) with Gen [@Cusumano-Towner:2019],  SymPy [@Meurer:2017], and MLJ [@Blaom:2019].

<!-- 
Citations to entries in paper.bib should be in
[rMarkdown](http://rmarkdown.rstudio.com/authoring_bibliographies_and_citations.html)
format.

For a quick reference, the following citation commands can be used:
- `@author:2001`  ->  "Author et al. (2001)"
- `[@author:2001]` -> "(Author et al., 2001)"
- `[@author1:2001; @author2:2001]` -> "(Author1 et al., 2001; Author2 et al., 2002)" -->

# Acknowledgements

Thanks to the Julia language's [@Julia-2017] excellent support for modularity, libraries like Soss can be built without the need to re-implement existing capabilities. For extensive libaries that made early Soss development possible, the authors would like to acknowledge

- Tamas Papp for [`DynamicHMC.jl`](https://github.com/tpapp/DynamicHMC.jl) and associated libraries
- Ed Scheinerman for the [`SimpleWorld.jl`](https://github.com/scheinerman/SimpleWorld.jl) ecosystem, which we use to track and reason about variable dependencies within a model
- Mathieu Besançon for ongoing work on [`Distributions.jl`](https://github.com/JuliaStats/Distributions.jl) [@Distributions.jl-2019], and for his patient tolerance for PPL-related nitpicks of this library

We would also like to thank Seth Axen for helpful discussions and recent contributions including connection to [ArviZ](https://github.com/arviz-devs/ArviZ.jl) [@arviz_2019], and the [Turing](https://github.com/TuringLang/Turing.jl) [@ge2018t], [Gen](https://github.com/probcomp/Gen) [@Cusumano-Towner:2019], and [MLJ](https://github.com/alan-turing-institute/MLJ.jl) [@Blaom:2019] teams for helpful discussions, and for making their libraries modular and open-source.


# References
