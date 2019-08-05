function realtypes(nt::Type{NamedTuple{S, T} } ) where {S, T} 
    NamedTuple{S, realtypes(T)}
end

realtypes(::Type{Tuple{A,B}} ) where {A,B} = Tuple{realtypes(A), realtypes(B)}
realtypes(::Type{Tuple{A,B,C}} ) where {A,B,C} = Tuple{realtypes(A), realtypes(B), realtypes(C)}
realtypes(::Type{Tuple{A,B,C,D}} ) where {A,B,C,D} = Tuple{realtypes(A), realtypes(B), realtypes(C), realtypes(D)}
realtypes(::Type{Tuple{A,B,C,D,E}} ) where {A,B,C,D,E} = Tuple{realtypes(A), realtypes(B), realtypes(C), realtypes(D), realtypes(E)}

realtypes(::Type{Array{T, N}}) where {T,N}= Array{realtypes(T),N}

realtypes(::Type{<: Real}) = Real
