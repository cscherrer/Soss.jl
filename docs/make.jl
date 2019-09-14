using Documenter
using Soss

makedocs(
    sitename = "Soss",
    format = Documenter.HTML(),
    modules = [Soss]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
