const PACKAGE_ROOT = dirname(dirname(@__FILE__))
const TESTROOT = joinpath(PACKAGE_ROOT, "test")
const DOCROOT = joinpath(PACKAGE_ROOT, "docs")
const DOCSOURCE = joinpath(DOCROOT, "src")
const EXAMPLESROOT = joinpath(PACKAGE_ROOT, "examples")
const EXAMPLES = [
    ("Linear model",                     "linear-model"),
    ]
