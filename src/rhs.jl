# An abstraction for the rhs of a Statement

abstract type RHS end

struct functionRHS <: RHS
    f 
    args 
    kwargs
end

struct distRHS <: RHS
    dist 
end

struct modelRHS <: RHS 
    m 
end