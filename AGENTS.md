# R Source Code - Agent Notes

## Overview

R is a functional programming language for statistical computing and graphics, originally developed by Robert Gentleman and Ross Ihaka. This is a mirror of the official R source from SVN, maintained at github.com/wch/r-source.

Current version: R Under development (unstable) r89117

## Repository Structure

### Top-Level Directories

- `src/` - Core R source code (~141K lines in main/ alone)
- `doc/` - Documentation (manuals, FAQ, notes)
- `tests/` - Test suite
- `tools/` - Build and development tools
- `share/` - Shared data files (encodings, licenses, etc.)
- `m4/` - Autoconf macros
- `po/` - Translations
- `build/` - Build output directory (created by build-r.sh)

### Source Code Structure (`src/`)

#### `src/main/` - Core Interpreter (108 C files)

The heart of R. Key files by size:
- `g_her_glyph.c` (271K) - Hershey glyph rendering
- `eval.c` (270K) - Expression evaluator and bytecode interpreter
- `connections.c` (213K) - I/O connections
- `gram.c` (207K) - Parser (generated from gram.y)
- `memory.c` (145K) - Memory management and garbage collection
- `envir.c` (126K) - Environment handling
- `engine.c` (120K) - Graphics engine
- `platform.c` (111K) - Platform-specific code
- `grep.c` (109K) - Pattern matching (uses PCRE2)
- `serialize.c` (95K) - Object serialization
- `errors.c` (85K) - Error handling

Other important files:
- `main.c` - Main entry point, REPL implementation
- `builtin.c` - Built-in primitive functions
- `arithmetic.c` - Arithmetic operations
- `apply.c` - Apply family functions
- `attrib.c` - Object attributes
- `character.c` - String handling
- `coerce.c` - Type coercion
- `context.c` - Execution contexts
- `deparse.c` - Converting expressions to strings
- `names.c` - Symbol table
- `objects.c` - Object system
- `par.c` - Graphics parameters
- `plot.c` - Base plotting
- `print.c` - Printing
- `subscript.c` - Subsetting operations
- `subassign.c` - Subset assignment

#### `src/include/` - Header Files

Key headers:
- `Defn.h` - Main internal definitions
- `Internal.h` - Internal function declarations
- `R.h` - Public R API
- `Rinternals.h` - Internal R structures
- `Parse.h` - Parser interface
- `Graphics.h` - Graphics system
- `Rconnections.h` - Connection objects

#### `src/library/` - Base R Packages

Core packages implemented in R + C:
- `base` - Base R functions
- `stats` - Statistical functions
- `graphics` - Graphics functions
- `grDevices` - Graphics devices
- `utils` - Utility functions
- `methods` - S4 object system
- `grid` - Grid graphics system
- `compiler` - Bytecode compiler
- `parallel` - Parallel computation
- `tools` - Package development tools
- `tcltk` - Tcl/Tk interface
- `datasets` - Example datasets
- `splines` - Spline functions
- `stats4` - S4 statistical functions
- `Recommended/` - Recommended packages (MASS, Matrix, etc.)

#### `src/modules/` - Loadable Modules

- `lapack/` - LAPACK linear algebra routines
- `internet/` - Internet access (libcurl, sockets)
- `X11/` - X11 graphics device

#### `src/nmath/` - Standalone Math Library

Statistical distributions and mathematical functions that can be used independently of R.

#### `src/appl/` - Applied Statistics Algorithms

Numerical algorithms from Applied Statistics journal.

#### `src/extra/` - External Libraries

Bundled external dependencies:
- `blas/` - Basic Linear Algebra Subprograms
- `intl/` - Internationalization
- `tre/` - Regular expressions
- `xdr/` - XDR serialization
- `tzone/` - Timezone data

#### `src/unix/` - Unix-specific Code

Unix/Linux/macOS platform support including:
- System interface
- Dynamic loading
- X11 support
- Embedding interface

#### `src/gnuwin32/` - Windows-specific Code

Windows platform support (not used on macOS/Linux).

## Key Architecture Components

### 1. Parser and Evaluator

The Read-Eval-Print Loop (REPL):
- Parser: `gram.y` (bison grammar) → `gram.c`
- Evaluator: `eval.c` - interprets R expressions
- Bytecode compiler: `compiler` package + bytecode interpreter in `eval.c`

### 2. Memory Management

- `memory.c` - Garbage collector, memory allocation
- Uses mark-and-sweep GC
- PROTECT/UNPROTECT macros for GC safety
- SEXP (S-expression) is the fundamental data structure

### 3. Object System

- S3: Generic functions in `objects.c`
- S4: `methods` package
- Attributes: `attrib.c`

### 4. Graphics

Two graphics systems:
- Base graphics: `graphics` package + `plot.c`, `par.c`
- Grid graphics: `grid` package

Graphics devices in `grDevices`:
- X11, Quartz (macOS), PDF, PNG, etc.

### 5. Connections

- `connections.c` - Unified I/O abstraction
- Supports files, URLs, pipes, compressed files, etc.

## Build System

### Build Script: `build-r.sh`

Our custom build script handles the complete build process. **This is the standard way to build R from this source.**

#### Build Process Steps:

1. **Download recommended packages** via `tools/rsync-recommended`
2. **Regenerate parser if needed**: Checks if `src/main/gram.y` is newer than `src/main/gram.c`
   - Uses `/opt/homebrew/opt/bison/bin/bison` (v3.8.2) if available
   - System bison (v2.3) is too old and doesn't support `%define` directive
   - Regenerates `src/main/gram.c` from `gram.y` when modified
3. **Configure**: Runs configure with Homebrew paths (xz, pcre2)
4. **Apply SVN workaround**: Creates SVNINFO file (see below)
5. **Build**: Compiles R in separate `build/` directory

#### Usage:

```bash
# Full build from scratch
./build-r.sh

# Rebuild after making changes (from build directory)
cd build && make

# Clean build
cd build && make clean && make
```

#### Key Files and Directories:

- **Source**: `/Users/davidhugh-jones/r-source/` - All source files stay here
- **Build**: `/Users/davidhugh-jones/r-source/build/` - Out-of-tree build directory
  - Contains compiled objects, libraries, and final R binary
  - `build/bin/R` - The R executable
- **Parser**: `src/main/gram.y` → `src/main/gram.c` (generated by bison)

#### Dependencies (macOS/Homebrew):

- `xz` (liblzma)
- `pcre2`
- `bison` (v3.8.2 from Homebrew, for parser regeneration)
- Various graphics libraries (cairo, pango, X11)

### Parser Regeneration

**Important**: R ships with a pre-generated `src/main/gram.c` (parser). When you modify `src/main/gram.y` (grammar file), you must regenerate `gram.c`:

```bash
# Option 1: Use build-r.sh (automatically checks and regenerates)
./build-r.sh

# Option 2: Manual regeneration
/opt/homebrew/opt/bison/bin/bison -y -l src/main/gram.y -o src/main/gram.c
cd build && make
```

**Note**: System bison (v2.3) is too old. Install homebrew bison: `brew install bison`

### SVN Workaround

Since this is a git mirror of SVN:
- Create `SVNINFO` file with revision info extracted from git-svn-id
- Build in separate directory to avoid cluttering source
- Run `make front-matter html-non-svn` to generate docs without SVN

## Documentation

- `doc/manual/*.texi` - Texinfo manuals:
  - R-intro - Introduction to R
  - R-lang - Language definition
  - R-exts - Writing R extensions
  - R-admin - Administration
  - R-data - Data import/export
  - R-ints - Internals
  - R-FAQ - FAQ

- `doc/notes/*.md` - Developer notes

## Testing

- `tests/` - Extensive test suite
- Tests organized by functionality
- Includes regression tests

## Development Notes

### Code Style

- Mix of C and Fortran
- Heavy use of macros (PROTECT, UNPROTECT, etc.)
- SEXP type for all R objects
- Attribute system for metadata

### Key Concepts

1. **SEXP** - Pointer to R object (S-expression)
2. **PROTECT/UNPROTECT** - GC protection
3. **Attributes** - Metadata on objects (names, class, dim, etc.)
4. **Environments** - Namespaces and scoping
5. **Promises** - Lazy evaluation
6. **Contexts** - Error handling and non-local exits

### Platform Support

- Unix/Linux: Primary platform
- macOS: Via `src/unix/` with Quartz graphics
- Windows: Via `src/gnuwin32/`

This build uses macOS (darwin25.1.0, aarch64).

## Resources

- Official: https://www.r-project.org/
- Source mirror: https://github.com/wch/r-source
- CRAN: https://cran.r-project.org/
- R Internals manual: Essential reading for understanding the codebase
