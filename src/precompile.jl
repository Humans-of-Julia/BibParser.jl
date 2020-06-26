function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(Base.create_expr_cache),String,String,Array{Pair{Base.PkgId,UInt64},1},Base.UUID})
    Base.precompile(Tuple{typeof(Base.require),Module,Symbol})
end