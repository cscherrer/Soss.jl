using Distributions: ValueSupport, VariateForm

struct MixedSupport <: ValueSupport end
struct MixedVariate <: VariateForm end

struct JointDistribution{A0,A,B,M} <: Distribution{MixedVariate, MixedSupport}
    model::Model{A,B,M}
    args::A0
end


function (m::Model)(nt::NamedTuple)
    badargs = setdiff(keys(nt), variables(m))
    isempty(badargs) || @error "Unused arguments $badargs"
    
    m = predictive(m, keys(nt)...)
    return JointDistribution(m, nt)
end

(m::Model)(;args...)= m((;args...))

(m::Model)() = JointDistribution(m, NamedTuple())

function (jd::JointDistribution)(nt::NamedTuple)
    jd2 = jd.model(nt)
    return JointDistribution(jd2.model, merge(jd.args, jd2.args))
end

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
