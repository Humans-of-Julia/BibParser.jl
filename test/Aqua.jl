@testset "Aqua.jl" begin
    # TODO: Fix the broken tests and remove the `broken = true` flag
    Aqua.test_all(
        BibParser;
        ambiguities = (broken = false,),
        deps_compat = false,
        piracies = (broken = false,)
    )

    @testset "Ambiguities: BibParser" begin
        Aqua.test_ambiguities(BibParser;)
    end

    @testset "Piracies: BibParser" begin
        Aqua.test_piracies(BibParser;)
    end

    @testset "Dependencies compatibility (no extras)" begin
        Aqua.test_deps_compat(
            BibParser;
            check_extras = false            # ignore = [:Random]
        )
    end
end
