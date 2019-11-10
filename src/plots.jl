using Plots

export eachplot

@userplot EachPlot

@recipe function plt(p::EachPlot)
    x,y = p.args
    label --> ""
    # color --> :black
    alpha --> 0.01
    m = Matrix(y)'
    x,m
end
