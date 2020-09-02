using Weave

# Run from Soss.jl/
weave("readme/README.jmd", out_path="./", doctype= "github", cache=:refresh, args=Dict(:seed => 6))
