@testset "Code linting (JET.jl)" begin
    JET.test_package(BibParser; target_modules = (BibParser,))
end
