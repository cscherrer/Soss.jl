using MLStyle

export canonical
using Lazy
canonical(x) = x

# TODO: Make sure local variables are handled properly (e.g. local function args)
function canonical(expr :: Expr)
    # @show expr
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
        
        :((iid($n))($dist)) => begin
            rn = r(n)
            rdist = r(dist)
            :(iid($rn,$rdist)) |> r
        end

        :($f($(args...))) => begin
            rf = r(f)
            rx = map(r,args)
            :($rf($(rx...)))
        end

        # TODO: This was intended to work around the closure issues by rewriting it as a local fucntion with all values passed explicitly as arguments. Doesn't seem to work, at least not yet
        :($x -> begin $lnn; $fbody end) => begin
            vs = setdiff(variables(fbody), variables(x))
            @gensym f
            pars = astuple(variables(x))
            pars = :($(Expr(:parameters)))
            for v in vs
                pushfirst!(pars.args, :($v=$v))
            end
            quote
                $f($pars) = $fbody
                $f
            end
        end |> r

        x => x
    end
end

function canonical(m :: Model)
    args = m.args :: Vector{Symbol}
    vals  = map(canonical, m.vals) 
    dists = map(canonical, m.dists) 
    retn = m.retn  
    data = m.data
    Model(args, vals, dists, retn, data)
end    

ex1 = :(map(1:10) do x x^2 end)

# canonical(ex1)
# canonical(linReg1D)