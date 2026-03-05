using BibParser, BibParser.BibTeX

using Aqua
using ExplicitImports
using JET
using Test
using TestItemRunner

@testset "Package tests: BibParser" begin
    include("Aqua.jl")
    include("ExplicitImports.jl")
    # include("JET.jl") # FIXME - update for julia 1.12
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

    @testset "duplicate keys error (#57)" begin
        duplicate_keys_str = """
        @article{Key,
            author   = "Author1",
            title    = "Title1",
            journal  = "Journal1",
            year     = 1901,
            volume   = "1",
            number   = "1",
        }

        @article{Key,
            author   = "Author2",
            title    = "Title2",
            journal  = "Journal2",
            year     = 1902,
            volume   = "2",
            number   = "2",
        }
        """

        @test_throws "Duplicate BibTeX entry key detected" parse_entry(duplicate_keys_str)

        parsed = @test_logs (:warn, r"Duplicate BibTeX entry key detected") parse_entry(duplicate_keys_str; check = :warn)
        @test haskey(parsed, "Key")
        @test parsed["Key"].title == "Title1" # first occurrence is kept

        parsed = @test_logs parse_entry(duplicate_keys_str; check = :none)
        @test haskey(parsed, "Key")
        @test parsed["Key"].title == "Title1" # first occurrence is kept
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
