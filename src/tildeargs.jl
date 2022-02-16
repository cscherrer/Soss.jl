struct TildeArgs{N,T,X,M}
    vars::NamedTuple{N,T}    # A named tuple of local variables used in the measure
    # X                      # The name of LHS variable, represented at the type level.
    # M                      # A type-level representation of the RHS expression 

    TildeArgs(vars::NamedTuple{N,T}, X, M) where {N,T} = new{N, T, Type{X}, Type{M}}(vars)
end

get_lhs(::Type{TildeArgs{N,T,X,M}}) where {N,T,X,M} = from_type(Soss._unwrap_type(X))
get_rhs(::Type{TildeArgs{N,T,X,M}}) where {N,T,X,M} = from_type(Soss._unwrap_type(M))