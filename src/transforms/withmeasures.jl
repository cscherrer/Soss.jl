using Soss

get_distname(x::Symbol) = Symbol(:_, x, :_dist)

"""
    withmeasures(m::DAGModel) -> Model

julia> m = @model begin
    σ ~ HalfNormal()
    y ~ For(10) do j
        Normal(0,σ)
    end
end;

julia> m_dists = Soss.withmeasures(m)
@model begin
        _σ_dist = HalfNormal()
        σ ~ _σ_dist
        _y_dist = For(10) do j
                Normal(0, σ)
            end
        y ~ _y_dist
    end

julia> ydist = rand(m_dists())._y_dist
For{GeneralizedGenerated.Closure{function = (σ, M, j;) -> begin
    M.Normal(0, σ)
end,Tuple{Float64,Module}},Tuple{Int64},Normal{Float64},Float64}(GeneralizedGenerated.Closure{function = (σ, M, j;) -> begin
    M.Normal(0, σ)
end,Tuple{Float64,Module}}((0.031328640120683524, Main)), (10,))

julia> rand(ydist)
10-element Array{Float64,1}:
  0.03454891487870426
  0.008832782323408313
 -0.007395186925623771
 -0.030669004243492004
 -0.01728630026691135
  0.011892877715064682
  0.025576319363013512
 -0.029323425779917773
 -0.020502677724193594
  0.04612690097957398
"""
function withmeasures(m::DAGModel)
    theModule = getmodule(m)
    m_init = DAGModel(theModule, m.args, NamedTuple(), NamedTuple(), nothing)

    function proc(st::Sample) 
        distname = get_distname(st.x)
        assgn = DAGModel(theModule, Assign(distname, st.rhs))
        sampl = DAGModel(theModule, Sample(st.x, distname))
        return merge(assgn, sampl)
    end
    
    proc(st::Arg) = nothing
    proc(st) = DAGModel(theModule, st)

    # Rewrite the statements of the model one by one. 
    m_new = foldl(statements(m); init=m_init) do m0,st
        merge(m0, proc(st))
    end
    return m_new
end

function withmeasures(d::AbstractModel)
    withmeasures(Model(d))(argvals(d)) | observations(d)
end

# TODO: Finish this
# function predict_measure(rng::AbstractRNG, d::ConditionalModel, post::AbstractVector{<:NamedTuple{N}}) where {N}
