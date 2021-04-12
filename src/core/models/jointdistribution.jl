struct ConditionalModel{A0,A,B,M} <: Distribution{MixedVariate, MixedSupport}
    model::DAGModel{A,B,M}
    args::A0
end

(jd::ConditionalModel)(nt::NamedTuple) = jd.model(merge(jd.args, nt))


# function (m::DAGModel)(nt::NamedTuple)
#     badargs = setdiff(keys(nt), variables(m))
#     isempty(badargs) || @error "Unused arguments $badargs"
    
#     m = predictive(m, keys(nt)...)
#     return ConditionalModel(m, nt)
# end

(m::DAGModel)(;args...)= m((;args...))

(m::DAGModel{A,B,M})(nt::NamedTuple) where {A,B,M} = ConditionalModel(m,nt)

function Base.show(io::IO, d :: ConditionalModel)
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
