
export logdensityof

using NestedTuples: lazymerge
import MeasureTheory

function MeasureBase.logdensityof(c::ConditionalModel{A,B,M}, x=NamedTuple()) where {A,B,M}
    _logdensityof(M, Model(c), argvals(c), observations(c), x)
end

export sourceLogdensityOf

sourceLogdensityOf(m::AbstractModel) = sourceLogdensityOf()(Model(m))

function sourceLogdensityOf()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            rhs = st.rhs
            @q begin
                _ℓ += Soss.logdensityof($rhs, $x)
                $x = Soss.predict($rhs, $x)
            end
        end

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

@gg function _logdensityof(M::Type{<:TypeLevel}, _m::Model, _args, _data, _pars)
    body = type2model(_m) |> sourceLogdensityOf() |> loadvals(_args, _data, _pars)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end

###############################################################################


function MeasureBase.logdensity_def(c::ConditionalModel{A,B,M}, x=NamedTuple()) where {A,B,M}
    @show c
    _logdensity_def(M, Model(c), argvals(c), observations(c), x)
end

export sourceLogdensityDef

sourceLogdensityDef(m::AbstractModel) = sourceLogdensityDef()(Model(m))

# function Base.convert(nt::NamedTuple, args...)
#     @show nt
#     @show args
#     for (n, t) in enumerate(stacktrace())
#         print("\t",n,". ")
#         println(t)
#     end

# end

function sourceLogdensityDef()
    function(_m::Model)
        proc(_m, st :: Assign)     = :($(st.x) = $(st.rhs))
        proc(_m, st :: Return)     = nothing
        proc(_m, st :: LineNumber) = nothing
        function proc(_m, st :: Sample)
            x = st.x
            rhs = st.rhs
            @q begin
                _ℓ += Soss.logdensity_def($rhs, $x)
                $x = Soss.predict($rhs, $x)
            end
        end

        wrap(kernel) = @q begin
            _ℓ = 0.0
            $kernel
            return _ℓ
        end

        buildSource(_m, proc, wrap) |> MacroTools.flatten
    end
end

@gg function _logdensity_def(M::Type{<:TypeLevel}, _m::Model, _args, _data, _pars)
    body = type2model(_m) |> sourceLogdensityDef() |> loadvals(_args, _data, _pars)
    @under_global from_type(_unwrap_type(M)) @q let M
        $body
    end
end

