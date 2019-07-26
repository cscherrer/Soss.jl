
export Simulation
struct Simulation
    f
    args
end

# Simulation(f, args...) = Simulation(f,args)

Base.rand(s::Simulation) = s.f(s.args...)

