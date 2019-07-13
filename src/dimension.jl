
export dimension
function dimension(expr :: Expr)
    # @show expr
    MLStyle.@match expr begin
        :($f |> $g)           => dimension(:($g($f)))
        # :(For($js) do $j $dist) => getTransform(:(For($j -> $dist, $js)))
        :(MixtureModel($d,$(args...))) => dimension(d)
        :(iid($n)($dist))     => n * dimension(dist)
        :(iid($n, $dist))     => n * dimension(dist)
        :(Dirichlet($k,$a))   => k 
        :(Dirichlet($a))      => length(a)
        :($dist($(args...)))  => dimension(dist)
        d                     => throw(MethodError(dimension, d))
    end
end