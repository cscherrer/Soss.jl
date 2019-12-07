Temporary note: here's how to build this
````julia

weave("writing/2019-JOSS/JOSS-Soss.jmd", cache=:refresh, doctype="github")
````




# Summary



m = @model n begin
    σ ~ HalfNormal(1)
    β ~ Normal(0, 1)
    α ~ Normal(0, 1)
    x ~ Normal(0, 1)
    yhat = α .+ β .* x
    y ~ For(n) do j
            Normal(yhat[j], σ)
        end
end;
 ```

# Mathematics

Single dollars ($) are required for inline mathematics e.g. $f(x) = e^{\pi/x}$

Double dollars make self-standing equations:

$$\Theta(x) = \left\{\begin{array}{l}
0\textrm{ if } x < 0\cr
1\textrm{ else}
\end{array}\right.$$


# Citations

Citations to entries in paper.bib should be in
[rMarkdown](http://rmarkdown.rstudio.com/authoring_bibliographies_and_citations.html)
format.

For a quick reference, the following citation commands can be used:
- `@author:2001`  ->  "Author et al. (2001)"
- `[@author:2001]` -> "(Author et al., 2001)"
- `[@author1:2001; @author2:2001]` -> "(Author1 et al., 2001; Author2 et al., 2002)"

# Figures

Figures can be included like this: ![Example figure.](figure.png)

# Acknowledgements

We acknowledge contributions from Brigitta Sipocz, Syrtis Major, and Semyeong
Oh, and support from Kathryn Johnston during the genesis of this project.

# References