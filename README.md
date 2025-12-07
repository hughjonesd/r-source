
# R with Pipe Assignment Operator

This is a fork of R that adds an experimental pipe assignment operator `<|>`.

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

For a detailed rationale, see <https://hughjonesd.github.io/case-for-pipe-assignment.html>.

The skinny:

* R is pass-by-value and allows complex subassignment
* Often we want to simply pass variables, or parts of them, through a function
* Doing this involves repeating oneself

In other words, it would be nice to write

```r
names(x)[1:5] <|> toupper()
```

instead of

```r
names(x)[1:5] <- toupper(names(x)[1:5])
```

and

```r
my_data[rows, cols] <|> as.numeric()
```

instead of

```r
my_data[rows, cols] <- as.numeric(my_data[rows, cols])
```

## Source Patch

You can build this version from github source using the build-R.sh script.
Alternatively, if you have an existing R source tree (from SVN or a tar file) and want to add the pipe assignment operator, you can apply the provided patch:

```bash
cd /path/to/r-source
patch -p1 < pipe-assignment-operator.patch
```

The patch file [`pipe-assignment-operator.patch`](pipe-assignment-operator.patch) modifies:
- `src/main/gram.y` - Grammar file with pipe assignment operator
- `src/main/gram.c` - Generated parser (regenerated from gram.y)
- `tests/reg-tests-pipe-assign.R` - Test suite for the operator

After applying the patch, build R as usual (see the [wch/r-source wiki](https://github.com/wch/r-source/wiki) for build instructions).

