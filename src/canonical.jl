using MLStyle

export canonical

canonical(x) = x

function canonical(expr :: Expr)
    r = canonical
    @match expr begin
        :($x |> $f) => begin
            rf = r(f)
            rx = r(x)
            :($rf($rx)) |> r
        end

        Expr(:do, :($g($x)), :($f)) => begin
            rg = r(g)
            rf = r(f)
            rx = r(x)            
            :($rg($rf, $rx)) |> r
        end        
        
        :($f($(args...))) => begin
            rf = r(f)
            rx = map(r,args)
            :($rf($(rx...)))
        end

        :(iid($n)($dist)) => begin
            rn = r(n)
            rdist = r(dist)
            :(iid($rn,$rdist)) |> r
        end

        x => x
    end
end

function canonical(m :: Model)
    newbody = Expr(:block, map(canonical, m.body.args)...)
    Model(m.args, newbody)
end    

ex1 = :(map(1:10) do x x^2 end)

# canonical(ex1)
# canonical(linReg1D)