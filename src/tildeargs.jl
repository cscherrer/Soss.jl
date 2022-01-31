struct TildeArgs{Ctx,Cfg,Xold,Vars,inArgs,inObs}
    context::Ctx             # A value (often a NamedTuple) that typically evolves throughout inference
    config::Cfg              # A NamedTuple holding configuration parameters, e.g. RNG
    x_oldval::Xold           # The previous value for the LHS. Because it may not be defined, this must be a `Maybe`
    vars::Vars  # A named tuple of local variables used in the measure
    inargs::inArgs              # A StaticBool indicating whether the current LHS is in the arguments
    inobs::inObs               # A StaticBool indicating whether the current LHS is in the observations
end