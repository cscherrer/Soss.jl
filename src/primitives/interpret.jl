export interpret

function interpret(m::ASTModel{A,B,M}) where {A,B,M}
    theModule = from_type(M)
    mk_function(theModule, _interpret(m.body))
end

function _interpret(ast::Expr)
    function branch(head, newargs)
        expr = Expr(head, newargs...)
        (head, newargs[1]) == (:call, :~) || return expr
        length(newargs) == 3 || return expr

        (_, x, d) = newargs
        :(($x, _ctx) = _tilde(Val{$(QuoteNode(x))}, $d, _ctx))
    end

    body = foldall(identity, branch)(ast)

    :(
        (_tilde, _ctx0) -> begin
            _ctx = _ctx0
            $(body.args...)
            return _ctx
        end
    ) 
end