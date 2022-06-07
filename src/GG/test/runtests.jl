
using JuliaVariables
using Test
using BenchmarkTools
using DataStructures


rmlines = NGG.rmlines

@testset "no kwargs" begin

@gg function f1(a)
    quote
        x -> a + x
    end |> rmlines
end

@test f1(1)(2) == 3

@gg function f2(a)
    quote
        x -> begin
            a += 2
            x + a
        end
    end |> rmlines
end

@test f2(1)(2) == 5


@gg function f3(a)
    quote
        k = 20
        x -> begin
            a += 2
            x + a + k
        end
    end
end

@test f3(1)(2) == 25

end


@testset "kwargs" begin

@gg function f4(a)
    quote
        function z(x, k=1)
            x + 20 + a + k
        end
    end
end

@test f4(10)(2) == 33
end

@testset "namedtuple" begin

@gg function f5(a)
    quote
        function z(x, k=1)
            (x=x, k=k, q=a)
        end
    end
end

@test f5(10)(2) == (x=2, k=1, q=10)
end


@testset "mk funcs" begin

f_ = mk_function(:((x, y) -> x + y))
@test f_(1, 2) == 3

f_ = mk_function(:(function (x, y) x + y end))
@test f_(1, 2) == 3


end

@testset "type encoding more datatypes" begin

@gg function f6(a)
    tp = (1, 2, 3)
    quote
        function z(x, k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f6(10)(2) == (x=2, k=(1, 2, 3), q=10)


@gg function f7(a)
    tp = (a1=1, a2=2, a3=3)
    quote
        function z(x, k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f7(10)(2) == (x=2, k=(a1=1, a2=2, a3=3), q=10)


@gg function f8(a)
    tp = "233"
    quote
        function z(x, k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f8(10)(2) == (x=2, k="233", q=10)


@gg function f9(a)
    tp = list(1, 2, 3)
    quote
        function z(x; k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f9(10)(2) == (x=2, k=list(1, 2, 3), q=10)
@test f9(10)(2; k=10) == (x=2, k=10, q=10)

end

@testset "runtime eval" begin

a = to_type(:(1 + 2))
@test :(1 + 2) == from_type(a)
@test string(from_type(a)) == string(:(1 + 2))


@test runtime_eval(1) == 1
@test mk_function(:(
    x -> x + 1
))(2) == 3

@test_throws Any mk_function(quote
    x -> x + 1
end)


@test runtime_eval(quote
    x -> x + 1
end)(1) == 2

end

@testset "self recursive" begin
    to_test = quote
        g(x, r=0) = x === 0 ? r : begin
            g = g # required for self recur
            g(x-1, r + x)
        end
        g(10)
    end |> runtime_eval

    g(x, r=0) = x === 0 ? r : g(x-1, r + x)
    expected = g(10)
    @test expected == to_test
end

@testset "self recursive" begin
    to_test = quote
        g(x, r=0) = x === 0 ? r : begin
            g = g # required for self recur
            g(x-1, r + x)
        end
        g(10)
    end |> runtime_eval

    g(x, r=0) = x === 0 ? r : g(x-1, r + x)
    expected = g(10)
    @test expected == to_test
end


@testset "support where clauses and return type annotations for @gg" begin
    @gg function foo(x::T) where T
        :(x, T)
    end
    @test foo(1) == (1, Int)
    @gg function bar(x::T) where T
        quote
            g = x + 20
            x = 10
            () -> begin
                x = g
                x
            end
        end
    end
    @test bar(2)() == 2 + 20

    @gg function foobar(x::T, y::A) where {T <: Number, A <: AbstractArray{T}}
        quote
            g = x + 20
            x = 10
            () -> begin
                x = g
                (A, x + y[1])
            end
        end
    end
    @test foobar(2, [3])() == (Vector{Int}, 2 + 20 + 3)
end

@testset "support default arguments" begin
    @gg function h(x, c)
        quote
            d = x + 10
            function g(x, y=c)
                x + y + d
            end
        end
    end
    @test h(1, 2)(3) == 16
end

module S
    run(y) = y + 1
end

struct K
    f1::Function
    f2::Function
end
@testset "specifying evaluation modules" begin
    @gg function g(m::Module, y)
        @under_global :m :(run(y))
    end
    @test g(S, 1) == 2

    @gg function h(m, y)
        @under_global :m quote
            c = m.f1(y)
            () -> begin c = m.f2(c) end
        end
    end
    k = K(x -> x + 1, x -> x * 9)
    next = h(k, 1)
    @test next() == 18
    @test next() == 18 * 9
end

@testset "test free variables of let bindings" begin
    @gg function test_free_of_let()
        quote
            let x = 1
                f = () -> begin
                    x * 3
                end
                x = 2
                f
            end
        end
    end
    @test test_free_of_let()() == 6
end

@testset "show something" begin
    f1 = mk_function(:(x -> x + 1))
    f2 = mk_function(:((x :: Int = 2, ) -> x + 1))
    @test f1(1) == 2
    @test f2() == 3
    println(f1)
    println(f2)
end

@testset "omit func argname: #34" begin
   f1 = mk_function(:( (:: Int) -> 0 ))
   @test f1(1) == 0
   @test_throws MethodError f1("")
end

@testset "support for 1-d arrays' type encoding: #42" begin
    from_type(to_type([1, 2, 3])) == [1, 2, 3]
    from_type(to_type([1, 2, "3"])) == [1, 2, "3"]
end

@testset "#54: fastmath/typeable Val" begin
    f = mk_function([:x],[],Base.FastMath.make_fastmath(:(0.5+1.0*x^2)))
    @test f(1) == 1.5
    @test f(10) == 100.5
end

struct PseudoModule{X, F}
    x :: X
    (+) :: F
end

@testset "struct as module" begin
    @gg f(y) = @under_global PseudoModule(10, *) :(x + y)
    @test f(2) == 20
end


@testset "#57, #59: big expression" begin

using GeneralizedGenerated: mk_function

function rand_ex()
    u = rand()
    c = randn()
    if u < 0.5
        return :(m1 + m2 + r² + $c)
    else
        return :(m1 * m2 / r² * $c)
    end
end

function gen_f_mkfunc(ex)
    return mk_function(@__MODULE__, rmlines(:((m1, m2, r²) -> $ex)))
end

function main(N::Int)
    for i in 1:N
        m1, m2, r² = rand(3)
        ex = rand_ex()
        f_mkfunc = gen_f_mkfunc(ex)
        f_mkfunc(m1, m2, r²)
    end
end

main(5_000)

@test true

end