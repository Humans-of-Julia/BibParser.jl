@testset "Extensive import coverage" begin
    @testset "Public input API" begin
        bib = "@misc{x, title={From IO}}"
        @test parse_bibliography(IOBuffer(bib); format = :BibTeX).entries[1].title ==
              "From IO"
        @test BibParser.parse_string(bib)["x"].title == "From IO"
        @test_throws ArgumentError parse_bibliography(bib; format = :Unknown)
        @test parse_bibliography("   ").format == :BibTeX
    end

    @testset "BibTeX grammar" begin
        bib = raw"""
        Free prefix.
        @string(monthname = "Jan")
        @string{journal = "Journal" # " of " # "Tests"}
        @preamble{"prefix" # monthname}
        @comment{This is a comment block}
        @article(key.with:symbols,
          author = {van Beethoven, Ludwig and {The Julia Project}},
          title = "Quoted " # {and {Nested}} # " Title",
          journal = journal,
          year = 2024,
          month = monthname,
          pages = {1--10},
          note = {Comma, equals = and # stay literal}
        )
        """
        document = parse_bibliography(bib; format = :BibTeX)
        @test length(document.entries) == 1
        entry = only(document.entries)
        @test entry.id == "key.with:symbols"
        @test entry.title == "Quoted and {Nested} Title"
        @test entry.in.journal == "Journal of Tests"
        @test entry.date.month == "Jan"
        @test entry.authors[1].particle == "van"
        @test entry.authors[2].last == "{The Julia Project}"
        @test occursin("equals =", entry.note)
        @test :string in map(block -> block.kind, document.blocks)
        @test :preamble in map(block -> block.kind, document.blocks)
        @test :comment in map(block -> block.kind, document.blocks)
        @test document.source == bib

        malformed = "@article{key, title={unterminated}"
        recovered = parse_bibliography(malformed; format = :BibTeX, check = :none)
        @test recovered.source == malformed
    end

    @testset "BibLaTeX grammar and aliases" begin
        bib = raw"""
        @online{dataset,
          editor = {Editor, Erin},
          title = {Dataset},
          year = {2024},
          doi = {10.1234/data},
          eprinttype = {zenodo},
          eprintclass = {dataset},
          location = {Paris},
          options = {useprefix=true},
          date = {2024-05}
        }
        """
        entry = only(parse_bibliography(bib; format = :BibLaTeX).entries)
        @test isempty(entry.authors)
        @test only(entry.editors).last == "Editor"
        @test entry.access.doi == "10.1234/data"
        @test entry.date == BibInternal.Date("", "05", "2024")
        @test entry.in.address == "Paris"
        @test entry.eprint.archive_prefix == "zenodo"
        @test entry.fields["options"] == "useprefix=true"
    end

    @testset "CFF 1.2 schema" begin
        minimal = """
        cff-version: 1.2.0
        message: Cite this work
        title: Go
        authors:
          - name: The Example Team
        """
        document = parse_bibliography(minimal; format = :CFF)
        @test isempty(document.diagnostics)
        @test length(document.entries) == 1
        @test document.entries[1].title == "Go"
        @test document.entries[1].authors[1].last == "The Example Team"
        @test !isempty(document.entries[1].id)
        @test document.source == minimal

        rich = """
        cff-version: 1.2.0
        message: Cite this work
        title: Software
        type: software
        version: 2.0
        date-released: "2024-02-29"
        repository-code: https://example.test/code
        doi: 10.1234/top
        identifiers:
          - type: doi
            value: 10.1234/identifier
        authors:
          - family-names: Lovelace
            given-names: Ada
            name-particle: de
            name-suffix: Jr.
        preferred-citation:
          type: article
          title: Preferred paper
          authors:
            - family-names: Hopper
              given-names: Grace
          journal: Notes
          year: 1952
        """
        preferred = only(parse_bibliography(rich; format = :CFF).entries)
        @test preferred.title == "Preferred paper"
        @test preferred.type == "article"
        @test preferred.authors[1].last == "Hopper"

        invalid = replace(minimal, "cff-version: 1.2.0" => "cff-version: 9.9.9")
        @test !isempty(parse_bibliography(invalid; format = :CFF).diagnostics)
    end

    @testset "CSL-JSON data model" begin
        csl = raw"""
        [
          {
            "id": "chapter",
            "type": "chapter",
            "title": "A Chapter",
            "author": [
              {"family":"Beethoven","given":"Ludwig","non-dropping-particle":"van","suffix":"Jr."},
              {"literal":"Standards Committee"}
            ],
            "editor": [{"family":"Editor","given":"Erin"}],
            "container-title": "Collected Work",
            "issued": {"date-parts":[[2024,2,29]]},
            "publisher": "Press",
            "publisher-place": "Paris",
            "page": "10-20",
            "ISBN": "9780000000000",
            "ISSN": "1234-5678",
            "DOI": "10.1234/chapter",
            "URL": "https://example.test/chapter",
            "volume": 3,
            "issue": 2
          },
          {"id":"rawdate","type":"report","title":"Report","issued":{"raw":"forthcoming"}}
        ]
        """
        document = parse_bibliography(csl; format = :CSL)
        @test isempty(document.diagnostics)
        @test length(document.entries) == 2
        chapter, report = document.entries
        @test chapter.type == "incollection"
        @test chapter.authors[1].particle == "van"
        @test chapter.authors[1].junior == "Jr."
        @test chapter.authors[2].last == "Standards Committee"
        @test chapter.booktitle == "Collected Work"
        @test chapter.date == BibInternal.Date("29", "2", "2024")
        @test chapter.in.publisher == "Press"
        @test chapter.in.address == "Paris"
        @test chapter.access.doi == "10.1234/chapter"
        @test report.type == "techreport"
        @test report.date.year == "forthcoming"
        @test all(!isempty(entry.raw.raw) for entry in document.entries)

        @test !isempty(parse_bibliography("null"; format = :CSL).diagnostics)
        @test !isempty(parse_bibliography("[1]"; format = :CSL).diagnostics)
    end

    @testset "RIS tagged grammar" begin
        ris = """
        ignored before first record
        TY  - JOUR
        ID  - one
        AU  - Lovelace, Ada
        AU  - Hopper, Grace
        KW  - computing
        KW  - history
        TI  - First line
              second line
        PY  - 1843/12/10
        SP  - 1
        EP  - 9
        ER  -
        TY  - GEN
        TI  - Record without terminator
        """
        document = parse_bibliography(ris; format = :RIS)
        @test length(document.entries) == 2
        first_entry, second_entry = document.entries
        @test length(first_entry.authors) == 2
        @test occursin("second line", first_entry.title)
        @test first_entry.date == BibInternal.Date("10", "12", "1843")
        @test first_entry.in.pages == "1--9"
        @test second_entry.type == "misc"
        @test !isempty(second_entry.id)
    end

    @testset "EndNote XML grammar" begin
        xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xml><records>
          <record><rec-number>1</rec-number><ref-type>Book Section</ref-type>
            <contributors><authors><author><style>Hopper, Grace</style></author></authors>
            <secondary-authors><author><style>Editor, Erin</style></author></secondary-authors></contributors>
            <titles><title><style>Chapter</style></title><secondary-title><style>Book</style></secondary-title></titles>
            <dates><year><style>1952</style></year></dates><publisher><style>Press</style></publisher>
            <pages><style>1-20</style></pages><isbn><style>9780000000000</style></isbn>
          </record>
          <record><rec-number>2</rec-number><ref-type>Web Page</ref-type>
            <titles><title><style>Website</style></title></titles>
          </record>
        </records></xml>
        """
        document = parse_bibliography(xml; format = :EndNote)
        @test isempty(document.diagnostics)
        @test length(document.entries) == 2
        @test document.entries[1].type == "incollection"
        @test document.entries[1].booktitle == "Book"
        @test only(document.entries[1].editors).last == "Editor"
        @test document.entries[1].in.publisher == "Press"
        @test document.entries[2].type == "misc"
        @test all(!isempty(entry.raw.raw) for entry in document.entries)
    end

    @testset "MODS 3.8 grammar" begin
        mods = """
        <modsCollection xmlns="http://www.loc.gov/mods/v3" version="3.8">
          <mods ID="m1">
            <typeOfResource>text</typeOfResource><genre>conference paper</genre>
            <titleInfo><nonSort>The</nonSort><title>Paper</title><subTitle>Subtitle</subTitle></titleInfo>
            <name type="personal"><namePart type="family">Turing</namePart><namePart type="given">Alan</namePart></name>
            <name type="corporate"><namePart>Computing Laboratory</namePart></name>
            <relatedItem type="host"><titleInfo><title>Proceedings</title></titleInfo></relatedItem>
            <originInfo><dateIssued>1936-05-01</dateIssued><publisher>Society</publisher><place><placeTerm>London</placeTerm></place></originInfo>
            <identifier type="doi">10.1234/paper</identifier><location><url>https://example.test</url></location>
          </mods>
          <mods ID="m2"><genre>book</genre><titleInfo><title>Book</title></titleInfo></mods>
        </modsCollection>
        """
        document = parse_bibliography(mods; format = :MODS)
        @test isempty(document.diagnostics)
        @test length(document.entries) == 2
        paper = document.entries[1]
        @test paper.type == "inproceedings"
        @test paper.title == "Paper"
        @test paper.booktitle == "Proceedings"
        @test paper.authors[1].last == "Turing"
        @test paper.authors[2].last == "Computing Laboratory"
        @test paper.date.year == "1936"
        @test paper.in.publisher == "Society"
        @test paper.access.doi == "10.1234/paper"
        @test document.entries[2].type == "book"
    end
end
