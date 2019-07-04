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
    m = canonical(m)
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
      , :HalfNormal => (v,args) -> :(SymPy.Normal($v,$(args...)))
      , :TDist => (v,args) -> :(SymPy.StudentT($v,$(args...)))
      , :Cauchy => (v,args) -> :(SymPy.Cauchy($v,$(args...)))
      , :HalfCauchy => (v,args) -> :(SymPy.Cauchy($v,0,$(args...)))
    #   , :For => (f,xs) => :()
      , :iid => (v, args) -> begin
                
                :()
            end
    ))

    sum(symlogpdf(expr,ctx) for expr in stochs)
end

a = @model begin
    x ~ Normal(0,1)
    y ~ Normal(0,1)
end

m = @model x,y begin
    α ~ Cauchy(0,5)
    β ~ Normal(0,1)
    σ ~ HalfCauchy(3)
    x0 ~ Normal(0,1)
    ε ~ HalfNormal(0,1)
    x ~ Normal(x0, ε)
    y0 ~ Normal(α + β * x , σ)
    y ~ Normal(y0, ε)
end

symlogpdf(m)
