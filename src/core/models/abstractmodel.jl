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

abstract type AbstractConditionalModel{M, Args, Obs} <: AbstractMeasure end

argstype(::AbstractModel{A,B,M}) where {A,B,M} = A

bodytype(::AbstractModel{A,B,M}) where {A,B,M} = B

getmodule(::Type{AMF}) where {A,B,M, AMF<:AbstractModel{A,B,M}} = from_type(M)
getmodule(::AbstractModel{A,B,M}) where {A,B,M} = from_type(M)

# getmoduletypencoding(::Type{AbstractModel{A,B}}) where  {M,A,O,AM<:AbstractModel{A,B}} = M
# getmoduletypencoding(::AbstractModel{A,B}) where  {M,A,O,AM<:AbstractModel{A,B}} = M

argvalstype(::AbstractModel{A}) where {A} = A
argvalstype(::Type{AM}) where {A,AM<:AbstractModel{A}} = A


obstype(::AbstractModel) = NamedTuple{(), Tuple{}}
obstype(::Type{<:AbstractModel}) = NamedTuple{(), Tuple{}}


(m::AbstractModel)(;argvals...)= m((;argvals...))

(m::AbstractModel{A})(args...) where {A} = m(A(args))

body(::AbstractModel{A,B}) where {A,B} = from_type(B)
body(::Type{AM}) where {A,B,AM<:AbstractModel{A,B}} = from_type(B)
