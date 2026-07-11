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

    @testset "don't copy fields from previous entries (#28)" begin
        bib_str = """
        @book{FroeseFischer1997,
            Address =      {Bristol, UK Philadelphia, Penn},
            Author =       {Froese Fischer, Charlotte and Brage, Tomas and
                            Jönsson, Per},
            Isbn =         {0-7503-0466-9},
            Publisher =    {Institute of Physics Publ},
            Title =        {Computational atomic structure : an {MCHF} approach},
            Year =         1997,
        }

        @article{Javanainen1988,
            author =       {J. Javanainen and J. H. Eberly and Qichang Su},
            title =        {Numerical Simulations of Multiphoton Ionization and
                            Above-Threshold Electron Spectra},
            journal =      {Physical Review A},
            volume =       38,
            number =       7,
            pages =        {3430-3446},
            year =         1988,
            doi =          {10.1103/physreva.38.3430},
            url =          {http://dx.doi.org/10.1103/PhysRevA.38.3430},
        }
        """

        parsed = parse_entry(bib_str)
        @test haskey(parsed, "FroeseFischer1997")
        @test haskey(parsed, "Javanainen1988")
        @test parsed["FroeseFischer1997"].authors != parsed["Javanainen1988"].authors
        @test parsed["FroeseFischer1997"].in.isbn == "0-7503-0466-9"
        @test isempty(parsed["Javanainen1988"].in.isbn)
    end

    @testset "duplicate keys error (#57)" begin
        bib_str = """
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

        @test_throws "Duplicate BibTeX entry key detected" parse_entry(bib_str)

        parsed = @test_logs (:warn, r"Duplicate BibTeX entry key detected") parse_entry(
            bib_str; check = :warn)
        @test haskey(parsed, "Key")
        @test parsed["Key"].title == "Title1" # first occurrence is kept

        parsed = @test_logs parse_entry(bib_str; check = :none)
        @test haskey(parsed, "Key")
        @test parsed["Key"].title == "Title1" # first occurrence is kept
    end

    @testset "BibTeX @string does not leak into next field (#32)" begin
        bib = """
        @string{zp = "Z. Phys."}

        @mastersthesis{GoerzDiploma2010,
            Author = {Goerz, Michael},
            Title = {Optimization of a Controlled Phasegate for Ultracold Calcium Atoms in an Optical Lattice},
            School = {Freie Universität Berlin},
            type = {{Diplomarbeit}},
            url = {http://michaelgoerz.net/research/diploma_thesis.pdf},
            Year = {2010},
        }
        """
        parsed = parse_entry(bib)
        first_author = parsed["GoerzDiploma2010"].authors[1]
        @test first_author.last == "Goerz"
        @test first_author.first == "Michael"
    end

    @testset "lossless BibTeX document preserves top-level blocks" begin
        bib = """
        Free text before entries.

        @string{jcp = "J. Chem. Phys."}

        @preamble{"\\newcommand{\\noop}[1]{}"}

        @comment{This comment should survive parsing.}

        @article{Key,
          author = {Lovelace, Ada},
          title = {Computing},
          journal = jcp,
          year = {1843}
        }

        Free text after entries.
        """

        document = parse_bibliography(bib; format = :BibTeX)
        @test document.format == :BibTeX
        @test length(document.entries) == 1
        @test document.entries[1].id == "Key"
        @test document.entries[1].raw.kind == "article"
        @test document.entries[1].raw.key == "Key"
        @test any(
            field -> field.name == "title" && field.value == "Computing",
            document.entries[1].raw.fields
        )
        @test :string in map(block -> block.kind, document.blocks)
        @test :preamble in map(block -> block.kind, document.blocks)
        @test :comment in map(block -> block.kind, document.blocks)
        @test count(block -> block.kind == :free, document.blocks) == 2
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

    @testset "CFF document API" begin
        content = read(joinpath(PACKAGE_ROOT, "examples", "CITATION.cff"), String)
        document = parse_bibliography(content; format = :CFF)
        @test document.format == :CFF
        @test isempty(document.diagnostics)
        @test length(document.entries) == 1
        @test document.entries[1].title == "Software paper"
        @test document.entries[1].access.doi == "10.1234/zenodo.123456"
    end
end

@testset "CSL-JSON" begin
    csl = """
    [
      {
        "id": "lovelace1843",
        "type": "article-journal",
        "title": "Computing",
        "author": [{"family": "Lovelace", "given": "Ada"}],
        "container-title": "Notes",
        "issued": {"date-parts": [[1843, 1, 1]]},
        "DOI": "10.0000/example",
        "URL": "https://example.test/paper",
        "volume": "1",
        "issue": "2",
        "page": "1-10"
      }
    ]
    """
    document = parse_bibliography(csl; format = :CSL)
    @test document.format == :CSL
    @test isempty(document.diagnostics)
    @test length(document.entries) == 1
    entry = document.entries[1]
    @test entry.id == "lovelace1843"
    @test entry.type == "article"
    @test entry.title == "Computing"
    @test entry.authors[1].last == "Lovelace"
    @test entry.date.year == "1843"
    @test entry.in.journal == "Notes"
end
