using Distributions: ValueSupport, VariateForm

struct MixedSupport <: ValueSupport end
struct MixedVariate <: VariateForm end

"""
    AbstractModel{AT,BT,MT,A,O}

Gives an abstract type for all Soss models

Type variables ending in T are type-level representations used to reconstruct


N gives the Names of arguments (each a Symbol)
B gives the Body, as an Expr
M gives the Module where the model is defined
"""
abstract type AbstractModel{AT,BT,MT,A,O} end

argstype(::AbstractModel{AT,BT,MT,A,O}) where {AT,BT,MT,A,O} = AT
argstype(::Type{AM}) where {AT,BT,MT,A,O,AM<:AbstractModel{AT,BT,MT,A,O}} = AT

bodytype(::AbstractModel{AT,BT,MT,A,O}) where {AT,BT,MT,A,O} = BT
bodytype(::Type{AM}) where {AT,BT,MT,A,O,AM<:AbstractModel{AT,BT,MT,A,O}} = BT

getmodule(::Type{AbstractModel{AT,BT,MT,A,O}}) where  {AT,BT,MT,A,O,AM<:AbstractModel{AT,BT,MT,A,O}} = from_type(MT)
getmodule(::AbstractModel{AT,BT,MT,A,O}) where {AT,BT,MT,A,O,AM<:AbstractModel{AT,BT,MT,A,O}} = from_type(MT)

getmoduletypencoding(::Type{AbstractModel{AT,BT,MT,A,O}}) where  {AT,BT,MT,A,O,AM<:AbstractModel{AT,BT,MT,A,O}} = MT
getmoduletypencoding(::AbstractModel{AT,BT,MT,A,O}) where  {AT,BT,MT,A,O,AM<:AbstractModel{AT,BT,MT,A,O}} = MT
