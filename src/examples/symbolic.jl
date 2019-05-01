using Pkg
Pkg.activate(".")
using Soss


using SymPy
import PyCall

stats = PyCall.pyimport_conda("sympy.stats", "sympy")
import_from(stats)

# macro symport(s)
#     str = "sympy.$s"
#     quote
#         $s = PyCall.pyimport_conda($str, "sympy")
#         import_from($s)
#     end
# end


import MacroTools: postwalk, @capture
using MLStyle


# function interpret(expr; ctx=Dict(), evalf=eval, evalx=eval)
#     # How to handle functions
#     vf(f::Expr) = interpret(f; ctx=ctx, evalf=evalf, evalx=evalx)

#     vf(f::Symbol) = get(ctx,f) do 
#         evalf(f) # if f is not found in ctx
#     end
#     vf(f) = f

#     # How to handle values
#     vx(x::Expr) = interpret(x; ctx=ctx, evalf=evalf, evalx=evalx)

#     vx(x::Symbol) = get(ctx,x) do 
#         evalx(x) # if x is not found in ctx
#     end
#     vx(x) = x

#     @match expr begin
#         :($f($(args...))) => vf(f)(map(vx, args)...)
#         x                 => vx(x)
#     end
# end

# macro interpret(expr)
#     interpret(expr; ctx=ctx) |> esc
# end

"""
    @symlogpdf(expr, params)

Transform a distributional statement
    v ~ dist(args...)
into an expression for the log-density

WARNING
For now, this only work with distributions that have the same name and parameterization in SymPy and Distributions.jl
# """
# function symlogpdf(expr, params)
#     params = params.args
#     vars = Symbol.(params ∩ Soss.symbols(expr))
#     @show vars

#     sym = Dict(v => SymPy.symbols(v) for v in vars )
#     @show sym

#     @match $expr begin
#         Expr(:block, args...) => sum(symlogpdf(x,params) for x in args)
#         :($x ~ $d($(args...))) => ctx[d](x, args...)
#         Expr(:call, f, args...) => ctx[f](args...)
#         :(x = val)              => nothing
#     end 

#     @assert @capture(expr, v_ ~ rhs_)
#     @show v 
#     @show rhs

#     # e.g., :(Normal(μ,σ)) -> :(SymPy.Normal(v,μ,σ))
#     rhs.args[1] = :(SymPy.$(rhs.args[1]))
#     splice!(rhs.args, 2:1, [v])
#     @show rhs

#     s = postwalk(rhs) do x
#         if x∈vars
#             sym[x]
#         else x
#         end
#     end
#     @show s

#     s = :(SymPy.density($s).pdf($(sym[v])) |> log)
#     s = sympy.expand(s,log=true,deep=false,force=true)
#     s = :(Meta.parse(repr($s)))
#     s 

# end 


# using MLStyle

# function symlogpdf(m :: Model) 
#     ctx = Dict{Symbol, Any}(
#           :+ => +
#         , :* => *
#         , :^ => ^
#     )
#     for x in m.args
#         merge!(ctx, Dict{Symbol, Any}(x => SymPy.symbols(x)))
#     end

#     for expr in m.body.args
#         merge!(ctx, @match expr begin
#             :($x = $v) => Dict{Symbol, Any}(x => v)
#             :($x ~ $d) => Dict{Symbol, Any}(x => SymPy.symbols(x))
#         end)
#     end

#     s = 0.0
#     for expr in m.body.args
#         s += @match expr begin
#             :($x ~ $d) => 1.0 # symlogpdf(x,d;ctx=ctx)
#             _          => 0.0
#         end
#     end
#     s

# end

# function symlogpdf(x,d;ctx=ctx)
#     @match d begin

#     end
# end



# symlogpdf(:(x ~ Normal(λ,√λ)), :((x,λ)))

# function symlogpdf(m :: Model)


# function symlogpdf(expr :: Expr)
#     quote
#         @match $expr begin 
#             $template => $action
#             _         => nothing
#         end
#     end
# end



# s = SymPy.density(stats.Normal(:x, :μ, :σ)).pdf(SymPy.symbols(:x)) |> log
# s = sympy.expand(s,log=true,deep=false,force=true)
# s.diff(:x)
# expr = :(Meta.parse(repr($s)))



# s = SymPy.density(stats.Normal(:x, :μ,:σ)).pdf(SymPy.symbols(:x)) |> log;
# s = sympy.expand(s,log=true,deep=false,force=true)



# s.diff(:x)
# expr = :(Meta.parse(repr($s)))

# SymPy.density(sympy.sympify("Normal(x,μ,σ)")).pdf(SymPy.symbols(:x))

using MacroTools: @capture, postwalk, @q



function symlogpdf(expr, ctx)

    @assert @capture(expr, v_ ~ dist_)

    if @capture(dist, d_(dargs__))
        newargs = map(dargs) do arg
            postwalk(arg) do x
                get(ctx, x, x)
            end
        end
    
        s = ctx[d](ctx[v],newargs)
    
    
    
        s = :(SymPy.density($s).pdf($(ctx[v])) |> log)
        s = @q expand($s,log=true,deep=false,force=true)
        eval(s) 
    
    else
        expr
    end

end 

function symlogpdf(m::Model)
    vs = variables(m)
    ctx = Dict{Symbol, Any}(v => SymPy.symbols(v) for v in vs )

    stochs = []
    for arg in m.body.args
        if @capture(arg, v_=x_)
            merge!(ctx, Dict(v => x ))
        else push!(stochs, arg)
        end
    end
    
    merge!(ctx, Dict(
        :Normal => (v,args) -> :(SymPy.Normal($v,$(args...)))
      , :TDist => (v,args) -> :(SymPy.StudentT($v,$(args...)))
      , :Cauchy => (v,args) -> :(SymPy.Cauchy($v,$(args...)))
      , :HalfCauchy => (v,args) -> :(SymPy.Cauchy($v,0,$(args...)))
    ))

    sum(symlogpdf(expr,ctx) for expr in stochs)
end

a = @model begin
    x ~ Normal(0,1)
    y ~ Normal(0,1)
end

m = @model y begin
    μ ~ Normal(0, 1)
    σ ~ HalfCauchy(1)
    x ~ TDist(3)
    ε ~ Normal(0, 1)
    y ~ Normal(x, ε)
end

symlogpdf(m)
