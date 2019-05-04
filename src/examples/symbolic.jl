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
