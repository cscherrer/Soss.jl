macro model(v,ex)
    body = :(function($v,) $ex end)
    Expr(:quote, prettify(body))
end

macro model(ex)   
    body = :(function() $ex end)
    Expr(:quote, prettify(body))
end
