
# using ResumableFunctions

export abc
function abc(m::Model, δ; kwargs...)
    r = makeRand(m)
    function next()
        while true
            x = r(;kwargs...)
            δ(x) && return x
        end
    end
    next
    
end
