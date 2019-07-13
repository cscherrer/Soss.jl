using Sobol

using ResumableFunctions

@resumable function sobols(n)
    it = SobolSeq(n)
    while true
        for p in next!(it)
            @yield p
        end
    end
end