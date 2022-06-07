function scoping(ast)
    rec = scoping
    @match ast begin
        :([$(frees...)]($(args...), ) -> begin $(stmts...) end) =>
            let stmts = map(rec, stmts),
                arw   = :(($(args...), ) -> begin $(stmts...) end)
                Expr(:scope, (), Tuple(frees), (), arw)
            end
        Expr(hd, tl...) => Expr(hd, map(rec, tl)...)
        a => a
    end
end
