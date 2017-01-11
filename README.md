# elm-compiler-docs
This guide is assembled by the Elm community, with no assistance from Elm's creator. It's a reverse engineering effort in progress. It's based on the 0.18 compiler. If you're new to Haskell or would appreciate a refresher, see [haskell-resources.md](haskell-resources.md) for some helpful resources and tutorials.

## Getting Started
Haskell and Cabal can be a pain to set up, especially so for the Elm compiler 0.18, which uses an earlier version of Haskell. The easiest way to get the codebase running on your computer is through [Elm Env](https://github.com/breezykermo/elm-env), a Docker image that sets up a contained Haskell environment in a container.

Once you have Elm Env up and running, navigate to `Elm-Platform/0.18`. From here you can build the compiler from source using the following commands:

```bash
$ cabal install elm-compiler
$ cabal install elm-make
```

These commands will build the compiler codebase. Note that, in order to keep the latest build in your path (inside the Docker container), you may have to run:

```bash
$ export PATH=$PATH:/Elm-Package/Elm-Platform/0.18/.cabal-sandbox/bin
```

Alternatively the executables can be found at `/Elm-Package/Elm-Platform/0.18/.cabal-sandbox/bin`. 

## elm-make

[Elm-make](https://github.com/elm-lang/elm-make) is the command-line tool that manages and invokes the elm-compiler when it is processing a single file. The codebase is much smaller and less complex than elm-compiler, and as such it provides a handy entry point to understanding the Elm compiler in depth.

There is a handy file in the elm-make source (the command-line tool that runs elm-compiler on a `.elm` file), called [TheMasterPlan.hs](https://github.com/elm-lang/elm-make/blob/master/src/TheMasterPlan.hs), that models each step in the build process, annotating the types of each intermediate representation. Evan has provided some helpful comments along the way that point to how each intermediate representation is generated, and what it is used for. The elm-make codebase provides the code for all the parts of 'the compiler' that we are familiar with--the CLI entry point, dependency crawling and aggregation, and the files that are generated as a result of the build.

You can trace the points at which it enters the Elm compiler codebase in [Compile.hs](https://github.com/elm-lang/elm-make/blob/master/src/Pipeline/Compile.hs). I would recommend thoroughly wrapping your head around the data types and build process in elm-make before deep-diving into the elm-compiler code itself.

## How the compiler works
The [entry point](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Compile.hs) of the compiler lists various passes over the source. (If you're new to compilers, read [this](https://github.com/thejameskyle/the-super-tiny-compiler).)

* Parse the source code
* "Canonicalize all variables, pinning down where they came from"
* Run type inference
* Nitpick (miscellaneous checks)
* Optimization
* Code generation

This process happen inside the `Result` type (defined [here](https://github.com/elm-lang/elm-compiler/blob/0.16/src/Reporting/Result.hs)). This is like Elm's `Result` type but on steroids, with lots of places to put information about errors. It's also declared as a monad, which for our purposes makes it work well with chained operations (i.e. bail out if there are any errors), and allows the use of [do notation](https://en.wikibooks.org/wiki/Haskell/do_notation).

`Result` is one of many tools defined under `Reporting` which are used to manage errors. A `Report` represents some kind of error that gets printed when your program fails to compile. Evan's 0.18 release greatly improved Elm's error reporting, and this is really one of the outstanding aspects of the Elm compiler.

A `Region` describes the place in the code where the error happened; other types can be bundled with `Region` using `Located a` defined [Reporting/Annotation.hs](https://github.com/elm-lang/elm-compiler/blob/master/src/Reporting/Annotation.hs). The kinds of errors are descibed in [Reporting/Error.hs](https://github.com/elm-lang/elm-compiler/blob/master/src/Reporting/Error.hs) which farms them out to submodules: Canonicalize, Docs, Pattern, Syntax, and Type. Errors can be rendered to human-readable text or to JSON (by `--format=json` but that might not actually work?).

Error detection starts by examining small pieces of code (parsing characters, duplicate record fields), expands out to larger ones (name and type conflicts within and across modules), and then focuses back in on specific things (the type of main, exhaustive pattern matches, documentation).

### AST
The Abstract Syntax Tree is the main intermediate representation of code. It is used throughout the stages of compilation.

#### Expresssions

A [fully general expression](https://github.com/elm-lang/elm-compiler/blob/0.16/src/AST/Expression/General.hs) has four type variables describing different pieces of information. An `Expr'` is a giant union type of possible Elm expressions, such as `Literal`, `Binop`, `Cmd`, `OutgoingPort`, etc. `Expr` is this, but with a top-level annotation that contains useful information about where the expression came from, and other debugging information. There are Source, Valid and Canonical versions of expressions, which represent the expressions at different stages of the compiler lifecycle: Source expressions are created by the parser, and when the compiler is complete they have been resolved to Canonical expressions.

These versions are type aliases that provide specific types for the type variables. Optimized expressions, apparently because they need less information, are a separate union type.

#### Declarations

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
Code generation traverses the AST and outputs JavaScript, with help from the `Language.ECMAScript3` Haskell package. The code is triggered from [Compiler.hs](https://github.com/elm-lang/elm-compiler/blob/master/src/Elm/Compiler.hs), entering the Generate directory through the `generate` function in [JavaScript.hs](https://github.com/elm-lang/elm-compiler/blob/master/src/Generate/JavaScript.hs). Much of the generate process occurs in [elm-make](https://github.com/elm-lang/elm-make), including the generation of `.elmi` and `.elmo` files, crawling dependencies, and the provision of [boiler JS code](https://github.com/elm-lang/elm-make/blob/master/src/Pipeline/Generate.hs) necessary for the JS runtime.

(Where are `.elmi` and `.elmo` temporary files generated and read? How are third-party libraries integrated?)

