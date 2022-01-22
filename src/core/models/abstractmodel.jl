# using Dists: ValueSupport, VariateForm

# struct MixedSupport <: ValueSupport end
# struct MixedVariate <: VariateForm end





"""
    AbstractModel{A,B}

Gives an abstract type for all Soss models

Type variables ending in T are type-level representations used to reconstruct


N gives the Names of arguments (each a Symbol)
B gives the Body, as an Expr
M gives the Module where the model is defined
"""
abstract type AbstractModel{A,B,M} <: AbstractKleisli end

abstract type AbstractConditionedModel{M, Args, Obs} <: AbstractMeasure end




argstype(::AbstractModel{A,B,M}) where {A,B,M} = A

bodytype(::AbstractModel{A,B,M}) where {A,B,M} = B

# argstype(::AbstractModel{A,B}) where {M,A,O} = AT
# argstype(::Type{AM}) where {M,A,O,AM<:AbstractModel{A,B}} = AT

# # bodytype(::AbstractModel{A,B}) where {M,A,O} = BT
# # bodytype(::Type{AM}) where {M,A,O,AM<:AbstractModel{A,B}} = BT

# getmodule(::AbstractModel{M}) where {M<:AbstractModel} = getmodule(M)

getmodule(::Type{AMF}) where {A,B,M, AMF<:AbstractModel{A,B,M}} = from_type(M)
getmodule(::AbstractModel{A,B,M}) where {A,B,M} = from_type(M)

# getmoduletypencoding(::Type{AbstractModel{A,B}}) where  {M,A,O,AM<:AbstractModel{A,B}} = M
# getmoduletypencoding(::AbstractModel{A,B}) where  {M,A,O,AM<:AbstractModel{A,B}} = M

argvalstype(::AbstractModel{A}) where {A} = A
argvalstype(::Type{AM}) where {A,AM<:AbstractModel{A}} = A


obstype(::AbstractModel) = NamedTuple{(), Tuple{}}
obstype(::Type{<:AbstractModel}) = NamedTuple{(), Tuple{}}


(m::AbstractModel)(;argvals...)= m((;argvals...))

(m::AbstractModel)(args...) = m(NamedTuple{Tuple(m.args)}(args...))
