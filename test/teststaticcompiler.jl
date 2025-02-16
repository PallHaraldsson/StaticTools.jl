# Setup
testpath = pwd()
scratch = tempdir()
cd(scratch)

## --- Times table, file IO, mallocarray

# Attempt to compile
# We have to start a new Julia process to get around the fact that Pkg.test
# disables `@inbounds`, but ironically we can use `--compile=min` to make that
# faster.
status = run(`julia --compile=min $testpath/scripts/times_table.jl`)
@test isa(status, Base.Process)
@test status.exitcode == 0

# Attempt to run
println("5x5 times table:")
status = run(`./times_table 5 5`)
@test isa(status, Base.Process)
@test status.exitcode == 0
@test parsedlm(Int64, c"table.tsv", '\t') == (1:5)*(1:5)'

## --- Random number generation

# Attempt to compile
# We have to start a new Julia process to get around the fact that Pkg.test
# disables `@inbounds`, but ironically we can use `--compile=min` to make that
# faster.
status = run(`julia --compile=min $testpath/scripts/rand_matrix.jl`)
@test isa(status, Base.Process)
@test status.exitcode == 0

# Attempt to run
println("5x5 random matrix:")
status = run(`./rand_matrix 5 5`)
@test isa(status, Base.Process)
@test status.exitcode == 0

## --- Test LoopVectorization integration

status = run(`julia --compile=min $testpath/scripts/loopvec_product.jl`)
@test isa(status, Base.Process)
@test status.exitcode == 0

# Attempt to run
println("10x10 table sum:")
status = run(`./loopvec_product 10 10`)
@test isa(status, Base.Process)
@test status.exitcode == 0
@test parsedlm(c"product.tsv",'\t')[] == 3025


## ---

cd(testpath)

## ---
