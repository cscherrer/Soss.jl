begin
    begin
        g = Core.Box()
        begin
              #= /home/redbq/Desktop/stable-dev/julia-community/GeneralizedGenerated.jl/src/GeneralizedGenerated.jl:41 =#
            begin
                  #= /home/redbq/Desktop/stable-dev/julia-community/GeneralizedGenerated.jl/test/runtests.jl:168 =#
                g.contents = (x, r = 0)->begin
                    begin
                        begin
                            if (Main).:(===)(x, 0)
                                r
                            else
                                g.contents = g.contents
                                g.contents((Main).:-(x, 1), (Main).:+(r, x))
                            end
                        end
                    end
                end
                  #= /home/redbq/Desktop/stable-dev/julia-community/GeneralizedGenerated.jl/test/runtests.jl:172 =#
                println(g.contents(10))
            end
        end
    end
end