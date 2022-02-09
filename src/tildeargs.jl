struct TildeArgs{X,M,V}
    x_name::X  # The name of LHS variable, represented at the type level.
    measure::M     # A type-level representation of the RHS expression 
    # x_oldval::Xold # The previous value for the LHS. Because it may not be defined, this must be a `Maybe`
    # ctx::Ctx       # A value (often a NamedTuple) that typically evolves throughout inference
    # cfg::Cfg       # A NamedTuple holding configuration parameters, e.g. RNG
    vars::V     # A named tuple of local variables used in the measure
    # inargs::inArgs # A StaticBool indicating whether the current LHS is in the arguments
    # inobs::inObs   # A StaticBool indicating whether the current LHS is in the observations
end