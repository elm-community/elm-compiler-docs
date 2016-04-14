# elm-compiler-docs
This guide is assembled by the Elm community, with no assistance from Elm's creator. It's a reverse engineering effort in progress. It's based on the 0.16 compiler.

## How to write and test patches
To come - someone with cabal knowledge write down how to compile the compiler and run tests

## How the compiler works
The [entry point](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Compile.hs) of the compiler lists various passes over the source. (If you're new to compilers, read [this](https://github.com/thejameskyle/the-super-tiny-compiler).)

* Parse the source code
* "Canonicalize all variables, pinning down where they came from"
* Run type inference
* Nitpick: a round of checks after type inference. This includes warning on missing annotations and verifying the type of `main`.
* Optimization
* Code generation

This process happen inside the `Result` type (defined [here](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Reporting/Result.hs)). This is like Elm's `Result` type but on steroids, with lots of places to put information about errors. It's also declared as a monad, which for our purposes makes it work well with chained operations (i.e. bail out if there are any errors).

`Result` is one of many tools defined under `Reporting` which are used to manage errors. A `Report` represents some kind of error that gets printed when your program fails to compile. A `Region` describes the place in the code where the error happened; other types can be bundled with `Region` using `Located a` defined `Reporting/Annotation.hs`. The kinds of errors are descibed in `Reporting/Error.hs` which farms them out to submodules: Canonicalize, Docs, Pattern, Syntax, and Type. Errors can be rendered to human-readable text or to JSON (by `--format=json` but that might not actually work?).

### AST
The Abstract Syntax Tree is the main intermediate representation of code. It is used throughout the stages of compilation.

A [fully general expression](https://github.com/elm-lang/elm-compiler/blob/0.16/src/AST/Expression/General.hs) has four type variables describing different pieces of information. An `Expr'` is a giant union type of possible expressions; and `Expr` is this with a top-level annotation. There are Source, Valid, and Canonical versions of expressions (that list is in order, I *think*). These versions are type aliases that provide specific types for the type variables. Optimized expressions, apparently because they need less information, are a separate union type.

A Declaration is anything that can be at the top level within a module: a definition, a union type, a type alias, a port, an infix declaration. There is also code for patterns, variables, literals, and types.

## Parse
To come

(Is `Validate.hs` not used anywhere?)

## Canonicalize
To come

## Type Inference
To come

## Nitpick
To come

## Generate
To come


