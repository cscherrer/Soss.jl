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
 - name: Metis
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
- Call to external inference libraries that use these or other included methods
- Build new models from `m`, for example using a known value for $mu$ or computing the Markov blanket at a node
- Find the symbolic log-density, using `SymPy.jl`
- Use the result of symbolic simplification to generated optimized code, often with significant performance benefits

At the time of this writing, Soss can connect (through the main library or optional add-ons) with Gen `[Cusumano-Towner:2019]`,  SymPy `[Meurer:2017]`, and MLJ `[Blaom:2019]`.

<!-- 
Citations to entries in paper.bib should be in
[rMarkdown](http://rmarkdown.rstudio.com/authoring_bibliographies_and_citations.html)
format.

For a quick reference, the following citation commands can be used:
- `@author:2001`  ->  "Author et al. (2001)"
- `[@author:2001]` -> "(Author et al., 2001)"
- `[@author1:2001; @author2:2001]` -> "(Author1 et al., 2001; Author2 et al., 2002)" -->

# Acknowledgements

The authors are grateful for 

We acknowledge contributions from Brigitta Sipocz, Syrtis Major, and Semyeong
Oh, and support from Kathryn Johnston during the genesis of this project.

# References