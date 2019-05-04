using MLStyle


canonicalize(x) = x


function canonicalize(expr :: Expr)
    r = canonicalize
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
        
        x => x
    end
end

ex1 = :(map(1:10) do x x^2 end)

canonicalize(ex1)
