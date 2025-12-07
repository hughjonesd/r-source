
# R with Pipe Assignment Operator

This is a fork of R that adds an experimental pipe assignment operator `<|>`.

## The Pipe Assignment Operator

The operator combines piping with assignment. `LHS <|> RHS` is parsed as `LHS <- RHS(LHS, ...)`.

### Examples

```r
x <|> foo()             # becomes  x <- foo(x)
x$elem <|> foo()        # becomes  x$elem <- foo(x$elem)
names(x) <|> toupper()  # becomes  names(x) <- toupper(names(x))
x <|> gsub("pattern", "replacement", x = _)
                        # becomes  x <- gsub("pattern", "replacement", x = x)
```

### Features

- Works with any valid left-hand side of `<-` (variables, subscripts, replacement functions)
- Supports the placeholder `_` in named arguments, like the `|>` operator
- Non-associative (chaining is not allowed)

### Rationale

For a detailed rationale, see https://hughjonesd.github.io/case-for-pipe-assignment.html

## About R

R is a language and environment for statistical computing and graphics. It is a GNU project which is similar to the S language and environment developed at Bell Laboratories.

For more information about R, visit https://www.r-project.org/

## Applying the Patch

If you have an existing R source tree (from SVN or a tar file) and want to add the pipe assignment operator, you can apply the provided patch:

```bash
cd /path/to/r-source
patch -p1 < pipe-assignment-operator.patch
```

The patch file [`pipe-assignment-operator.patch`](pipe-assignment-operator.patch) modifies:
- `src/main/gram.y` - Grammar file with pipe assignment operator
- `src/main/gram.c` - Generated parser (regenerated from gram.y)
- `tests/reg-tests-pipe-assign.R` - Test suite for the operator

After applying the patch, build R as usual (see the [wch/r-source wiki](https://github.com/wch/r-source/wiki) for build instructions).

## Building

See the [wch/r-source wiki](https://github.com/wch/r-source/wiki) for instructions on building R from source, or use the provided `build-r.sh` script.
