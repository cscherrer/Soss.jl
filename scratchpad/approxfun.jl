using ApproxFun

function smoothness(f::Fun)
	s = f.space
	∫ = DefiniteIntegral(s)
	∂² = Derivative(s,2)
	return Number(-∫ * (∂² * f)^2)
end

s = Chebyshev()
ℓ(x) = @inbounds smoothness(Fun(s,x)) - x[1]^2 - x[2]^2

using ForwardDiff

ForwardDiff.gradient(ℓ, randn(10))

using TransformVariables
t = as((x=as(Vector, 10),))

using SampleChainsDynamicHMC
chain = initialize!(DynamicHMCChain, ℓ, t)









smoothness(f)



julia> using ApproxFun

julia> function smoothness(f)
           s = f.space
           ∫ = DefiniteIntegral(s)
           -∫ * (Derivative(s,2) * f)^2
       end
smoothness (generic function with 1 method)

julia> x = Fun(identity, 0..1)
Fun(Chebyshev(0..1),[0.5, 0.5])

julia> f = exp(x);

julia> smoothness(f)
-3.1945280494653217 on ApproxFunBase.AnyDomain()



function b(i)
    Derivative(2) * Fun(s,[zeros(i-1);1.0])
end

b(4)

function Sᵢⱼ(i,j)
    (DefiniteIntegral(s) * Multiplication(b(i)) * b(j)).coefficients[1]
end

Sᵢⱼ(7,5)

function makeS(n, space=Chebyshev())
    z =  Fun(Ultraspherical(2), zeros(n))
    b = [ z; z;[ Derivative(2) * Fun(space,[zeros(j-1);1.0; zeros(n-j+2)]) for j in 3:n]]
    S = Matrix{Float64}(undef, n, n)
    for j in 1:n
        for i in 1:n
            S[i,j] = prod((DefiniteIntegral() * Multiplication(b[i],space) * b[j]).coefficients)
        end
    end
    return S
end

n = 10
makeS(20)
