using Distributions: ValueSupport, VariateForm

struct Conditional{A0,Obs,A,B,M} <: Distribution{MixedVariate, MixedSupport}
    model::Model{A,B,M}
    args::A0
    obs::Obs
end


(cm::Conditional)(nt::NamedTuple) = Conditional(cm.model, merge(cm.args, nt), cm.obs)

import Base

Base.:|(m::Model, nt::NamedTuple) = Conditional(m, NamedTuple(), nt)

Base.:|(d::JointDistribution, nt::NamedTuple) = Conditional(d.model, d.args, nt)

function Base.:|(cm::Conditional, nt::NamedTuple) 
    new_obs = merge(cm.obs, nt)
    @assert new_obs == merge(nt, cm.obs)
    Conditional(cm.model, cm.args, new_obs)
end

# function (m::Model)(nt::NamedTuple)
#     badargs = setdiff(keys(nt), variables(m))
#     isempty(badargs) || @error "Unused arguments $badargs"
    
#     m = predictive(m, keys(nt)...)
#     return JointDistribution(m, nt)
# end

# (cm::Model)(;args...)= m((;args...))

# (m::Model{A,B,M})(nt::NamedTuple) where {A,B,M} = JointDistribution(m,nt)

# function Base.show(io::IO, d :: JointDistribution)
#     m = d.model
#     println(io, "Joint Distribution")
#     print(io, "    Bound arguments: [")
#     join(io, fieldnames(arguments(d)), ", ")
#     println(io, "]")
#     print(io, "    Variables: [")
#     join(io, setdiff(toposort(m),arguments(m)), ", ")
#     println(io, "]\n")
#     println(io, convert(Expr, m))
# end
