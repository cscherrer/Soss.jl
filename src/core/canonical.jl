using MLStyle

export canonical
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

        Expr(:block, body...) => Expr(:block, canonical.(body)...)

        Expr(:do, :(For($x)), :($f)) => begin
            rf = r(f)
            rx = r(x)

            :(For($rf, $rx)) |> r
        end        


        Expr(:do, :(For($(x...))), :($f)) => begin
            rf = r(f)
            rx = r.(x)

            rxtup = Expr(:tuple, rx...)
            :(For($rf, $rxtup)) |> r
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
        # :($x -> begin $lnn; $fbody end) => begin
        #     vs = setdiff(variables(fbody), variables(x))
        #     @gensym f
        #     pars = astuple(variables(x))
        #     pars = :($(Expr(:parameters)))
        #     for v in vs
        #         pushfirst!(pars.args, :($v=$v))
        #     end
        #     quote
        #         $f($pars) = $fbody
        #         $f
        #     end
        # end |> r

        x => x
    end
end

function canonical(m :: Model)
    args = m.args :: Vector{Symbol}
    vals  = map(canonical, m.vals) 
    dists = map(canonical, m.dists) 
    retn = m.retn  
    Model(getmodule(m), args, vals, dists, retn)
end    

ex1 = :(map(1:10) do x x^2 end)

# canonical(ex1)
# canonical(linReg1D)
