

function rejection(m)
    r = makeRand(m)
    function f(data)
        prop = r(;data...)
        while NamedTupleTools.select(prop, data) != data
            prop = r(;data...)
        end
        return prop
    end
end
