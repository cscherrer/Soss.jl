using Distributions: ValueSupport, VariateForm

struct MixedSupport <: ValueSupport end
struct MixedVariate <: VariateForm end

struct JointDistribution{A0,A,B,M} <: Distribution{MixedVariate, MixedSupport}
    model::Model{A,B,M}
    args::A0
end

(jd::JointDistribution)(nt::NamedTuple) = JointDistribution(jd.model, merge(jd.args, nt))


(m::Model)(;args...)= JointDistribution(m,(;args...))

(m::Model)(nt::NamedTuple) = JointDistribution(m,nt)

function Base.show(io::IO, d :: JointDistribution)
    m = d.model
    println(io, "Joint Distribution")
    print(io, "    Bound arguments: [")
    join(io, fieldnames(arguments(d)), ", ")
    println(io, "]")
    print(io, "    Variables: [")
    join(io, setdiff(toposort(m),arguments(m)), ", ")
    println(io, "]\n")
    println(io, convert(Expr, m))
end
