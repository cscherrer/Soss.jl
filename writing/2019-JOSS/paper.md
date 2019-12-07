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
    affiliation: "1, 2" # (Multiple affiliations must be quoted)
  - name: Taine Zhao
    affiliation: 2
affiliations:
 - name: Senior Data Scientist, Metis
   index: 1
 - name: Institution 2
   index: 2
date: 7 Dec 2019
bibliography: bibliography.bib
---

# Summary

Probabilistic programming is a rapidly growing field, but is still far from mainstream use, due at least in part to a common diconnect between performance and ease of use. Soss aims to achieve the best of both worlds, by offering a simple mathematical syntax and specialized code generation behind the scenes.

For example, here's a simple Gaussian model:

```julia
m = @model σ,n begin
    μ ~ Cauchy(0,1)
    x ~ For(n) do j
            Normal(μ,σ)
        end
end
```

Given this, a user can do things like

- Specify the $\sigma$ and $n$ arguments, and "forward sample" from the model (`rand`)
- Compute the log-density (`logpdf`)
- Call to external inference libraries that use these or other included methods
- Build new models from `m`, for example using a known value for $\mu$
- Find the symbolic log-density, using `SymPy.jl`
- Use the result of symbolic simplification to optimize 

At the time of this writing, Soss can connect (through the main library or optional add-ons) with Gen `[Cusumano-Towner:2019:GGP:3314221.3314642]`, MLJ `[anthony_blaom_2019_3541506]`, SymPy `[10.7717/peerj-cs.103]` (via `SymPy.jl`).

# Citations
<!-- 
Citations to entries in paper.bib should be in
[rMarkdown](http://rmarkdown.rstudio.com/authoring_bibliographies_and_citations.html)
format.

For a quick reference, the following citation commands can be used:
- `@author:2001`  ->  "Author et al. (2001)"
- `[@author:2001]` -> "(Author et al., 2001)"
- `[@author1:2001; @author2:2001]` -> "(Author1 et al., 2001; Author2 et al., 2002)" -->

# Figures
<!-- 
Figures can be included like this: ![Example figure.](figure.png) -->

# Acknowledgements

We acknowledge contributions from Brigitta Sipocz, Syrtis Major, and Semyeong
Oh, and support from Kathryn Johnston during the genesis of this project.

# References