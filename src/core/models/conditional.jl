using Distributions: ValueSupport, VariateForm

struct ConditionalModel{AT,BT,MT,A,O} <: AbstractModel{AT,BT,MT,A,O}
    model :: Model{AT,BT,MT}
    args :: A
    obs :: O
end


(cm::ConditionalModel)(nt::NamedTuple) = ConditionalModel(cm.model, merge(cm.args, nt), cm.obs)

import Base

Base.:|(m::Model, nt::NamedTuple) = ConditionalModel(m, NamedTuple(), nt)

Base.:|(d::JointDistribution, nt::NamedTuple) = ConditionalModel(d.model, d.args, nt)

function Base.:|(cm::ConditionalModel, nt::NamedTuple) 
    new_obs = merge(cm.obs, nt)
    @assert new_obs == merge(nt, cm.obs)
    ConditionalModel(cm.model, cm.args, new_obs)
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


|(m::Soss.Model,y) = ConditionalModel(m,NamedTuple(), y)
|(m::Soss.JointDistribution,y) = ConditionalModel(m.model,m.args, y)

m = @model begin
    x ~ Normal()
    y ~ Normal()
end

m() | (y=2.0,)
