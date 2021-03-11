using Soss


gps = @model speed,n,t begin
    x ~ For(1:n) do i
        Normal(μ = speed * t[i])
    end
    return x
end

radar = @model speed,n begin
    v ~ For(1:n) do i
        Normal(speed, 5.0)
    end
end

fullmodel = @model n,t begin
    speed ~ Normal(0.0, 100.0)
    x ~ gps(;speed, n, t)
    v ~ radar(;speed, n)
end

n = 10
t = 1:10

truth = rand(fullmodel(;n, t))
v = truth.v

post = fullmodel(;n, t) |(v=truth.v,)

dynamicHMC(post)




logdensity(post, truth)

speed = truth.speed
x = truth.x
v = truth.v

_ℓ = 0.0
_ℓ += logdensity(Normal(0.0, 100.0), speed)
speed = predict(Normal(0.0, 100.0), speed)
_ℓ += logdensity(gps(; speed, n, t), x)
x = predict(gps(; speed, n, t), x)
_ℓ += logdensity(radar(; speed, n), v)
v = predict(radar(; speed, n), v)
_ℓ
