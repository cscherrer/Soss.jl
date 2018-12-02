import Distributions.pdf
import Distributions.logpdf
# import Base.rand

struct Delta{T}
    x :: T
end

rand(δ::Delta{T} where T) = δ.x

function pdf(δ::Delta{T}, y::T) where T
    if δ.x == y
        Inf
    else
        0
    end
end

function logpdf(δ::Delta{T}, y::T) where T
    if δ.x == y
        Inf
    else
        -Inf
    end
end


function pdf(δ::Delta{T}, ys :: Vector{T}) where T
     pdf.(δ,ys) |> prod
end

function logpdf(δ::Delta{T}, ys :: Vector{T}) where T
    logpdf.(δ,ys) |> sum
end
