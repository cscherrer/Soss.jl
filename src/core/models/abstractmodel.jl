# using Dists: ValueSupport, VariateForm

# struct MixedSupport <: ValueSupport end
# struct MixedVariate <: VariateForm end


"""
    AbstractModelFunction{A,B}

Gives an abstract type for all Soss models

Type variables ending in T are type-level representations used to reconstruct


N gives the Names of arguments (each a Symbol)
B gives the Body, as an Expr
M gives the Module where the model is defined
"""
abstract type AbstractModelFunction{A,B,M} <: AbstractModel end


abstract type AbstractModel{A,B,M,Args,Obs} <: AbstractKleisli end

argstype(::AbstractModel{A,B,M,Args,Obs}) where {A,B,M,Args,Obs} = A
argstype(::Type{AM}) where {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = A

bodytype(::AbstractModel{A,B,M,Args,Obs}) where {A,B,M,Args,Obs} = B
bodytype(::Type{AM}) where {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = B

# argstype(::AbstractModelFunction{A,B}) where {M,A,O} = AT
# argstype(::Type{AM}) where {M,A,O,AM<:AbstractModelFunction{A,B}} = AT

# # bodytype(::AbstractModelFunction{A,B}) where {M,A,O} = BT
# # bodytype(::Type{AM}) where {M,A,O,AM<:AbstractModelFunction{A,B}} = BT

# getmodule(::AbstractModel{M}) where {M<:AbstractModel} = getmodule(M)

getmodule(::Type{AMF}) where {A,B,M, AMF<:AbstractModelFunction{A,B,M}} = from_type(M)
getmodule(::AbstractModelFunction{A,B,M}) where {A,B,M} = from_type(M)

# getmoduletypencoding(::Type{AbstractModelFunction{A,B}}) where  {M,A,O,AM<:AbstractModelFunction{A,B}} = M
# getmoduletypencoding(::AbstractModelFunction{A,B}) where  {M,A,O,AM<:AbstractModelFunction{A,B}} = M

argvalstype(::AbstractModelFunction{A}) where {A} = A
argvalstype(::Type{AM}) where {A,AM<:AbstractModelFunction{A}} = A


obstype(::AbstractModelFunction) = NamedTuple{(), Tuple{}}
obstype(::Type{<:AbstractModelFunction}) = NamedTuple{(), Tuple{}}


(m::AbstractModelFunction)(;argvals...)= m((;argvals...))

(m::AbstractModelFunction)(args...) = m(NamedTuple{Tuple(m.args)}(args...))
