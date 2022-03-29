struct TildeArgs{N,T,M}
    vars::NamedTuple{N,T}    # A named tuple of local variables used in the measure
    # X                      # The name of LHS variable, represented at the type level.
    # M                      # A type-level representation of the RHS expression 

    TildeArgs(vars::NamedTuple{N,T}, M) where {N,T} = new{N, T, Type{M}}(vars)
end

get_rhs(::Type{TildeArgs{N,T,M}}) where {N,T,M} = from_type(Soss._unwrap_type(M))

get_rhs(::TildeArgs{N,T,M}) where {N,T,M} = from_type(Soss._unwrap_type(M))