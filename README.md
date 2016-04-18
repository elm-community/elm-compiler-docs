# elm-compiler-docs
This guide is assembled by the Elm community, with no assistance from Elm's creator. It's a reverse engineering effort in progress. It's based on the 0.16 compiler.

## How to write and test patches
To come - someone with cabal knowledge write down how to compile the compiler and run tests

## How the compiler works
The [entry point](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Compile.hs) of the compiler lists various passes over the source. (If you're new to compilers, read [this](https://github.com/thejameskyle/the-super-tiny-compiler).)

* Parse the source code
* "Canonicalize all variables, pinning down where they came from"
* Run type inference
* Nitpick (miscellaneous checks)
* Optimization
* Code generation

This process happen inside the `Result` type (defined [here](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Reporting/Result.hs)). This is like Elm's `Result` type but on steroids, with lots of places to put information about errors. It's also declared as a monad, which for our purposes makes it work well with chained operations (i.e. bail out if there are any errors), and allows the use of [do notation](https://en.wikibooks.org/wiki/Haskell/do_notation).

`Result` is one of many tools defined under `Reporting` which are used to manage errors. A `Report` represents some kind of error that gets printed when your program fails to compile. A `Region` describes the place in the code where the error happened; other types can be bundled with `Region` using `Located a` defined `Reporting/Annotation.hs`. The kinds of errors are descibed in `Reporting/Error.hs` which farms them out to submodules: Canonicalize, Docs, Pattern, Syntax, and Type. Errors can be rendered to human-readable text or to JSON (by `--format=json` but that might not actually work?).

Error detection starts by examining small pieces of code (parsing characters, duplicate record fields), expands out to larger ones (name and type conflicts within and across modules), and then focuses back in on specific things (the type of main, exhaustive pattern matches, documentation).

### AST
The Abstract Syntax Tree is the main intermediate representation of code. It is used throughout the stages of compilation.

A [fully general expression](https://github.com/elm-lang/elm-compiler/blob/0.16/src/AST/Expression/General.hs) has four type variables describing different pieces of information. An `Expr'` is a giant union type of possible expressions; and `Expr` is this with a top-level annotation. There are Source, Valid, and Canonical versions of expressions (that list is in order, I *think*). These versions are type aliases that provide specific types for the type variables. Optimized expressions, apparently because they need less information, are a separate union type.

A Declaration is anything that can be at the top level within a module: a definition, a union type, a type alias, a port, an infix declaration. There is also code for patterns, variables, literals, and types.

### Parse
Parsing is the first stage of compilation, and is built around the Parsec library. Parsing is organized by parsers for expressions, declarations, literals, types, etc. The `IParser a` type is a parser that attempts to parse a string into an `a` (think JSON decoders). The parser's job is to transform valid code into the AST, and to detect and provide helpful error messages for invalid code.

The [parser entry point](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Parse/Parse.hs#L23-L41) validates (`Validate.hs`) the declarations for syntax errors (not including parse errors). Such errors include type annotations missing definitions, ports without annotations, duplicate report field names, and too many/too few type variables. Validation also ensures that ports do not occur outside of the main module; the `isRoot` parameter refers to the root module (i.e. Main), not the root user.

### Canonicalize
Canonicalization enriches the AST with more information in preparation for type inference. It determines what is visible where, and ensures there are no scoping problems. Canonicalization also sorts declarations by dependency.

### Type Inference
There's no shortage of academic papers on type inference, and what Elm has is relatively basic, but still quite complex. Type inference is a constraint-solving algorithm that works by unifying constraints to produce the most general possible type given the constraints.

(I don't really know what's going on but Evan had some tidbits here: https://github.com/elm-lang/elm-compiler/issues/1281)

### Nitpick
Nitpick is a collection of mostly-unrelated checks that happen after type inference. Nitpicking verifies the type of `main`, adds warnings for missing type annotations, and (I think?) flags inexhaustive pattern matches.

### Generate
Code generation traverses the AST and outputs JavaScript, with help from the `Language.ECMAScript3` Haskell package.

(Where are `.elmi` and `.elmo` temporary files generated and read? How are third-party libraries integrated?)

