using Distributions: ValueSupport, VariateForm

struct MixedSupport <: ValueSupport end
struct MixedVariate <: VariateForm end

"""
    AbstractModel{A,B,M,Args,Obs}

Gives an abstract type for all Soss models

Type variables ending in T are type-level representations used to reconstruct


N gives the Names of arguments (each a Symbol)
B gives the Body, as an Expr
M gives the Module where the model is defined
"""
abstract type AbstractModel{A,B,M,Args,Obs} end

argstype(::AbstractModel{A,B,M,Args,Obs}) where {A,B,M,Args,Obs} = AT
argstype(::Type{AM}) where {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = AT

bodytype(::AbstractModel{A,B,M,Args,Obs}) where {A,B,M,Args,Obs} = BT
bodytype(::Type{AM}) where {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = BT

getmodule(::Type{AbstractModel{A,B,M,Args,Obs}}) where  {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = from_type(MT)
getmodule(::AbstractModel{A,B,M,Args,Obs}) where {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = from_type(MT)

getmoduletypencoding(::Type{AbstractModel{A,B,M,Args,Obs}}) where  {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = MT
getmoduletypencoding(::AbstractModel{A,B,M,Args,Obs}) where  {A,B,M,Args,Obs,AM<:AbstractModel{A,B,M,Args,Obs}} = MT
