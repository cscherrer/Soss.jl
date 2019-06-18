using Distributions
using ResumableFunctions
import Distributions.logpdf


export Stream
struct Stream
    init # x -> P(s)
    next # (s,x) -> P(s)
end

@resumable rand(d::Stream)

    while true
        @yield
    end
end

# TODO: Clean up this hack
iid(n::Int) = dist -> iid(n,dist)

iid(dist) = iid(Nothing, dist)

rand(d::iid) = rand(d.dist, d.shape)

Distributions.logpdf(d::iid,x) = sum(logpdf.(d.dist,x))



using ResumableFunctions

@resumable function fibonacci()
  a = 0
  b = 1
  while true
    @yield a
    a, b = b, a+b
  end
end

@resumable function stream(init, next)
    s = init()
    while true
        x = @yield s
        s = next(s,x)
    end
end

init = randn
next(s,x) = 