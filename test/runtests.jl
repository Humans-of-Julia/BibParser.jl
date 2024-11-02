using BibParser, BibParser.BibTeX

using Aqua
using ExplicitImports
using JET
using Test
using TestItemRunner

@testset "Package tests: BibParser" begin
    include("Aqua.jl")
    include("ExplicitImports.jl")
    include("JET.jl")
    include("TestItemRunner.jl")
end

const PACKAGE_ROOT = pkgdir(BibParser)

@testset "BibTeX" begin
    for file in ["test.bib", "error.bib"]
        println("\nstart $file")
        parsed = parse_file(joinpath(PACKAGE_ROOT, "examples", "$file"))

        for (k, e) in pairs(parsed)
            println("|--->$(e.id)")
            for fn in fieldnames(typeof(e))
                println("|     |----$(string(fn)) -> parsed!") # TODO: better printing
            end
            for (n, v) in pairs(e.fields)
                println("|     |----$n -> $v")
            end
            println("|")
        end
    end
end

@testset "CFF" begin
    files = [
        ("CITATION.cff", true),
        ("invalid_yaml.cff", false),
        ("invalid_version.cff", false),
        ("invalid_schema.cff", false)
    ]
    @testset "$file" for (file, expected_result) in files
        parsed, result = parse_file(joinpath(PACKAGE_ROOT, "examples", file), :CFF)

        @info result
        @info expected_result
        @test result == expected_result
    end
end
