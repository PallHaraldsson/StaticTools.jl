# StaticTools

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://brenhinkeller.github.io/StaticTools.jl/dev)
[![Build Status](https://github.com/brenhinkeller/StaticTools.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/brenhinkeller/StaticTools.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/brenhinkeller/StaticTools.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/brenhinkeller/StaticTools.jl)

Tools to enable [StaticCompiler.jl](https://github.com/tshort/StaticCompiler.jl)-based static compilation of Julia code to standalone native binaries by eliding GC allocations and `llvmcall`-ing all the things.

This package currently requires Julia 1.8+

Caution: this package should be considered experimental at present, and involves a lot of juggling of pointers

The stack-allocated statically-sized `StaticString`s in this package are heavily inspired by the techniques used in [JuliaSIMD/ManualMemory.jl](https://github.com/JuliaSIMD/ManualMemory.jl); you can use that package via [StrideArraysCore.jl](https://github.com/JuliaSIMD/StrideArraysCore.jl) or [StrideArrays.jl](https://github.com/chriselrod/StrideArrays.jl) to obtain fast stack-allocated statically-sized arrays which should also be StaticCompiler-friendly.

### Examples
```julia
# This is all StaticCompiler-friendly
using StaticTools # `] add https://github.com/brenhinkeller/StaticTools.jl` to get latest main

function print_args(argc::Int, argv::Ptr{Ptr{UInt8}})
    # c"..." lets you construct statically-sized, stack allocated `StaticString`s
    # We also have m"..." and MallocString if you want the same thing but on the heap
    printf(c"Argument count is %d:\n", argc)
    for i=1:argc
        # iᵗʰ input argument string
        pᵢ = unsafe_load(argv, i) # Get pointer
        strᵢ = MallocString(pᵢ) # Can wrap to get high-level interface
        println(strᵢ)
        # No need to `free` since we didn't allocate this memory
    end
    println(c"That was fun, see you next time!")
    return 0
end

# Compile executable
using StaticCompiler # `] add https://github.com/tshort/StaticCompiler.jl` to get latest
filepath = compile_executable(print_args, (Int64, Ptr{Ptr{UInt8}}), "./")
```
and...
```
shell> ls -lh $filepath
  -rwxr-xr-x  1 user  staff   8.5K Feb 10 02:36 print_args

shell> ./print_args 1 2 3 4 5.0 foo
Argument count is 7:
./print_args
1
2
3
4
5.0
foo
That was fun, see you next time!

shell> hyperfine './print_args hello there'
Benchmark 1: ./print_args hello there
  Time (mean ± σ):       2.2 ms ±   0.5 ms    [User: 0.8 ms, System: 0.0 ms]
  Range (min … max):     1.5 ms …   5.5 ms    564 runs

  Warning: Command took less than 5 ms to complete. Results might be inaccurate.
```

Or, for an example with arrays:
```julia
using StaticTools # `] add https://github.com/brenhinkeller/StaticTools.jl` to get latest main
function times_table(argc::Int, argv::Ptr{Ptr{UInt8}})
    argc == 3 || return printf(c"Incorrect number of command-line arguments\n")
    rows = parse(Int64, argv, 2)            # First command-line argument
    cols = parse(Int64, argv, 3)            # Second command-line argument

    M = MallocArray{Int64}(undef, rows, cols)
    @inbounds for i=1:rows
        for j=1:cols
            M[i,j] = i*j
        end
    end
    printf(M)
    free(M)
end

using StaticCompiler # `] add https://github.com/tshort/StaticCompiler.jl` to get latest
filepath = compile_executable(times_table, (Int64, Ptr{Ptr{UInt8}}), "./")
```
which gives us...
```
shell> ls -lh $filepath
-rwxr-xr-x  1 user  staff   8.9K Feb 15 14:58 times_table

shell> ./times_table 12, 7
1   2   3   4   5   6   7
2   4   6   8   10  12  14
3   6   9   12  15  18  21
4   8   12  16  20  24  28
5   10  15  20  25  30  35
6   12  18  24  30  36  42
7   14  21  28  35  42  49
8   16  24  32  40  48  56
9   18  27  36  45  54  63
10  20  30  40  50  60  70
11  22  33  44  55  66  77
12  24  36  48  60  72  84
```

`MallocArray`s can be `reshape`d and `reinterpret`ed  without causing any new allocations. Unlike base `Array`s, `getindex` produces fast views by default when indexing memory-contiguous slices.
```julia
julia> function times_table(argc::Int, argv::Ptr{Ptr{UInt8}})
           argc == 3 || return printf(c"Incorrect number of command-line arguments\n")
           rows = parse(Int64, argv, 2)            # First command-line argument
           cols = parse(Int64, argv, 3)            # Second command-line argument

           M = MallocArray{Int64}(undef, rows, cols)
           @inbounds for i=1:rows
               for j=1:cols
                   M[i,j] = i*j
               end
           end
           printf(M)
           M = reinterpret(Int32, M)
           println(c"\n\nThe same array, reinterpreted as Int32:")
           printf(M)
           free(M)
       end
times_table (generic function with 1 method)

julia> filepath = compile_executable(times_table, (Int64, Ptr{Ptr{UInt8}}), "./")
"/Users/user/times_table"

shell> ./times_table 3 3
1	2	3
2	4	6
3	6	9


The same array, reinterpreted as Int32:
1	2	3
0	0	0
2	4	6
0	0	0
3	6	9
0	0	0
```
