using MonteCarloMeasurements

# Expected value of x log-weighted by ℓ
function expect(x,ℓ)
    w = exp(ℓ - maximum(ℓ))
    mean(x*w) / mean(w)
end

x = Particles(5000,TDist(3))
ℓ = logpdf(Normal(),x) - logpdf(TDist(3), x)

expect(x,ℓ)
expect(x^2,ℓ)
expect(x^3,ℓ)
expect(x^4,ℓ)

# Now sample z ~ Normal()

z = Particles(5000,Normal())

expect(z,ℓ)
expect(z^2,ℓ)
expect(z^3,ℓ)
expect(z^4,ℓ)

# And now a new weighted variable

y = Particles(5000,TDist(3))
ℓ += logpdf(Normal(),y) - logpdf(TDist(3), y)

expect(y,ℓ)
expect(y^2,ℓ)
expect(y^3,ℓ)
expect(y^4,ℓ)

expect(x+y,ℓ)
expect((x+y)^2,ℓ)

expect(x+z,ℓ)
expect((x+z)^2,ℓ)
