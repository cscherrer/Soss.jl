using Distributions: ValueSupport, VariateForm

struct MixedSupport <: ValueSupport end
struct MixedVariate <: VariateForm end

abstract type AbstractModel{Args,Obs,A,B,M} <: Distribution{MixedVariate, MixedSupport}
    model::Model{A,B,M}
    args::A0
    obs::Obs
end

function argnames(::AbstractModel) end

function observations(::AbstractModel) end

function graph(m::AbstractModel) end

argstype

obstype

bodytype

modeltype

moduletype

###############

arguments

sampled

assigned

parameters

variables

toposort



getmodule
