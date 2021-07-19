function zigzag(m::ModelClosure, T = 1000.0; c=10.0, adapt=false) where {A,B}

    ℓ = Base.Fix1(logdensity, m)

    t = as(m)

    function f(x)
        (θ, logjac) = transform_and_logjac(t, x)
        -ℓ(θ) - logjac
    end

    d = t.dimension

    function partiali()
        ith = zeros(d)
        function (x,i)
            ith[i] = 1
            sa = StructArray{ForwardDiff.Dual{}}((x, ith))
            δ = f(sa).partials[]
            ith[i] = 0
            return δ
        end
    end

    ∇ϕi = partiali()

    # Draw a random starting points and velocity

    t0 = 0.0
    x0 = randn(d)
    θ0 = randn(d)

    pdmp(∇ϕi, t0, x0, θ0, T, c*ones(d), ZigZag(sparse(I(d)), 0*x0); adapt=adapt)

end
