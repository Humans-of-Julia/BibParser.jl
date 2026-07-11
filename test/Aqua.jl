@testset "Aqua.jl" begin
    Aqua.test_all(BibParser; deps_compat = false)

    @testset "Dependencies compatibility (no extras)" begin
        Aqua.test_deps_compat(BibParser; check_extras = false)
    end
end
