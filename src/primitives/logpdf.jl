
export logpdf

function Distributions.logpdf(c::ConditionalModel{A,B,M}, x) where {A,B,M}
    _logpdf(M, Model(c), argvals(c), merge(obs(c), x))
end

function Distributions.logpdf(c::ConditionalModel{A,B,M}, x, ::typeof(logpdf)) where {A,B,M}
    _logpdf(M, Model(c), argvals(c), merge(obs(c), x))
end



@gg M function _logpdf(_::Type{M}, _m::Model, _args, _data) where M <: TypeLevel{Module}
    Expr(:let,
        Expr(:(=), :M, from_type(M)),
        type2model(_m) |> sourceLogpdf() |> loadvals(_args, _data))
end

export sourceLogpdf

sourceLogpdf(m::AbstractModel) = sourceLogpdf()(Model(m))

function sourceLogpdf()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Sample)     = :(_ℓ += logpdf($(st.rhs), $(st.x)))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> flatten
    end
end
