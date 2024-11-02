@testset "Code linting (JET.jl)" begin
    JET.test_package(BibParser; target_defined_modules = true)
end
