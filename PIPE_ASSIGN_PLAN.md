# Implementation Plan: Pipe Assignment Operator `<|>`

## Overview

Add a new operator `<|>` that combines piping with assignment, analogous to magrittr's `%<>%`.

**Syntax:** `LHS <|> RHS` transforms to `LHS <- RHS(LHS, ...)`

**Examples:**
```r
x <|> foo(bar)              →  x <- foo(x, bar)
a[1] <|> sqrt()             →  a[1] <- sqrt(a[1])
names(x) <|> toupper()      →  names(x) <- toupper(names(x))
x <|> sub("a", "b", x = _)  →  x <- sub("a", "b", x = x)
```

## Implementation Steps

### 1. Lexer Changes (gram.y, ~line 3585)

**Location:** In the `case '<':` section

**Current code:**
```c
case '<':
    if (nextchar('=')) {
        yylval = install_and_save("<=");
        return LE;
    }
    if (nextchar('-')) {
        yylval = install_and_save("<-");
        return LEFT_ASSIGN;
    }
    if (nextchar('<')) {
        if (nextchar('-')) {
            yylval = install_and_save("<<-");
            return LEFT_ASSIGN;
        }
        else
            return ERROR;
    }
    yylval = install_and_save("<");
    return LT;
```

**Add after the `<-` check:**
```c
if (nextchar('|')) {
    if (nextchar('>')) {
        yylval = install_and_save("<|>");
        return PIPE_ASSIGN;
    }
    else {
        // Backtrack: we saw '<|' but not '>'
        // This is an error: '<' followed by '|'
        xxcharcount -= 1;  // Put back the '|'
        yylval = install_and_save("<");
        return LT;
    }
}
```

**Parsing issue #1: Lexer lookahead**
- Need to check 3 characters ahead: `<`, `|`, `>`
- If we see `<|` without `>`, must backtrack
- The current lexer handles this pattern (see `<<-` for similar 3-char lookahead)

### 2. Token Declaration (gram.y, ~line 404)

Add new token:
```yacc
%token PIPE_ASSIGN
```

### 3. Precedence Declaration (gram.y, ~line 425)

**Ban chaining by making non-associative:**
```yacc
%nonassoc PIPE_ASSIGN
```

**Rationale:**
- `x <|> f() <|> g()` is almost certainly a user error
- Making it non-associative causes a parse error, which is clearer than generating broken code
- Users should use regular pipes for chaining: `x <|> f(); x <|> g()`

### 4. Grammar Rule (gram.y, ~line 497)

Add after LEFT_ASSIGN rule:
```yacc
| expr PIPE_ASSIGN expr  { $$ = xxpipeassign($1, $3, &@1, &@3); setId(@$); }
```

### 5. Semantic Function (gram.y, ~line 1262, after xxpipe)

Implement `xxpipeassign()`:

```c
static SEXP xxpipeassign(SEXP lhs, SEXP rhs, YYLTYPE *lloc_lhs, YYLTYPE *lloc_rhs)
{
    SEXP ans;

    if (GenerateCode) {
        // Validate RHS is a function call
        if (TYPEOF(rhs) != LANGSXP)
            raiseParseError("RHSnotFnCall", rhs, NO_VALUE, NULL, lloc_rhs,
                _("The pipe assignment operator requires a function call as RHS (%s:%d:%d)"));

        // Duplicate the LHS for reading
        SEXP lhs_read = duplicate_sexp(lhs);

        // Check for placeholder in RHS function name
        if (checkForPlaceholder(R_PlaceholderToken, CAR(rhs)))
            raiseParseError("placeholderInRHSFn", R_NilValue, NO_VALUE, NULL, lloc_rhs,
                _("pipe placeholder cannot be used in the RHS function (%s:%d:%d)"));

        // OPTIONAL: Handle extractor chain placeholders: _$a[1]$b
        // Only include if reusing code from xxpipe() is trivial
        #ifdef SUPPORT_EXTRACTOR_CHAINS
        SEXP phcell = findExtractorChainPHCell(R_PlaceholderToken, rhs, rhs, lloc_rhs);
        if (phcell != NULL) {
            SETCAR(phcell, lhs_read);
            PRESERVE_SV(ans = xxbinary(install("<-"), lhs, rhs));
            RELEASE_SV(lhs_read);
            goto cleanup;
        }
        #endif

        // Handle top-level placeholder in arguments
        SEXP placeholder_found = NULL;
        for (SEXP a = CDR(rhs); a != R_NilValue; a = CDR(a)) {
            if (CAR(a) == R_PlaceholderToken) {
                if (TAG(a) == R_NilValue)
                    raiseParseError("placeholderNotNamed", rhs, NO_VALUE, NULL, lloc_rhs,
                        _("pipe placeholder can only be used as a named argument (%s:%d:%d)"));
                if (placeholder_found != NULL)
                    raiseParseError("tooManyPlaceholders", rhs, NO_VALUE, NULL, lloc_rhs,
                        _("pipe placeholder may only appear once (%s:%d:%d)"));
                placeholder_found = a;
            }
        }

        if (placeholder_found != NULL) {
            SETCAR(placeholder_found, lhs_read);
            PRESERVE_SV(ans = xxbinary(install("<-"), lhs, rhs));
        } else {
            // Default: prepend LHS to arguments
            check_rhs(rhs, lloc_rhs);
            SEXP fun = CAR(rhs);
            SEXP args = CDR(rhs);
            SEXP new_call = lcons(fun, lcons(lhs_read, args));
            PRESERVE_SV(ans = xxbinary(install("<-"), lhs, new_call));
        }
    }
    else {
        PRESERVE_SV(ans = R_NilValue);
    }

#ifdef SUPPORT_EXTRACTOR_CHAINS
cleanup:
#endif
    RELEASE_SV(lhs);
    RELEASE_SV(rhs);
    return ans;
}
```

**Key implementation details:**

1. **LHS Duplication:** Duplicate the LHS parse tree to use as argument to RHS function

2. **Placeholder handling:**
   - Named arguments only: `x <|> foo(y = _)`
   - Single placeholder check
   - Optional: Extractor chains if trivial to reuse from xxpipe()

3. **No pipe-bind support:** Simpler implementation

### 6. Helper Function for SEXP Duplication

Need to add or use existing function to duplicate SEXP trees:

```c
static SEXP duplicate_sexp(SEXP s)
{
    // This may already exist - check existing codebase
    // Otherwise implement recursive duplication of parse tree
    if (s == R_NilValue || s == NULL)
        return s;

    SEXP dup;
    switch (TYPEOF(s)) {
        case SYMSXP:
            return s;  // Symbols are interned, can reuse
        case LANGSXP:
            PROTECT(dup = allocSExp(LANGSXP));
            SETCAR(dup, duplicate_sexp(CAR(s)));
            SETCDR(dup, duplicate_sexp(CDR(s)));
            SET_TAG(dup, duplicate_sexp(TAG(s)));
            // Copy attributes if any
            UNPROTECT(1);
            return dup;
        case LISTSXP:
            // Similar to LANGSXP
            // ... implementation
        default:
            return s;  // Constants can be reused
    }
}
```

**Parsing issue #3: LHS duplication complexity**
- The LHS can be arbitrarily complex: `obj$field[[i]]$subfield`
- Must create a complete copy of the parse tree
- The copy will be evaluated once (as argument), original used as assignment target

### 7. Token Name String (gram.y, ~line 2342)

Add to yytname array:
```c
"PIPE_ASSIGN", "'<|>'",
```

## Parsing Issues and Edge Cases

### Issue #1: Lexical Ambiguity

**Problem:** `x < |> y` vs `x <|> y`
- Spaces shouldn't matter for operators
- `<|>` must be recognized as single token even with whitespace

**Solution:** The lexer reads character-by-character without regard to whitespace in operator context. `< |> y` would tokenize as `LT PIPE y`, not `PIPE_ASSIGN`.

**Mitigation:** Document that `<|>` must be written without internal spaces

### Issue #2: LHS Evaluation Semantics

**Important: Replacement functions evaluate LHS only once**

R's replacement function semantics ensure correct evaluation:

```r
names(x) <|> toupper()
# Becomes: names(x) <- toupper(names(x))
# R evaluates this as: x <- `names<-`(x, toupper(names(x)))
# The names(x) on RHS is evaluated ONCE, result passed to `names<-`
```

Similarly for subscripting:
```r
x[i] <|> sqrt()
# Becomes: x[i] <- sqrt(x[i])
# R evaluates: x <- `[<-`(x, i, sqrt(`[`(x, i)))
# The x[i] is evaluated ONCE via `[`(x, i)
```

**For simple variables:**
```r
x <|> f()
# Becomes: x <- f(x)
# x appears twice in parse tree but this is fine - it's just a symbol lookup
```

**For function calls as LHS:**
```r
f() <|> g()  # f() called twice - unlikely use case
# Becomes: f() <- g(f())
```

**Mitigation:**
- Replacement functions and subscripting work correctly (most common cases)
- Simple variables work correctly
- Function calls as LHS are unusual and documented
- Matches magrittr `%<>%` behavior

### Issue #3: Complex Assignment Targets

**Problem:** Ensuring all valid LHS of `<-` work with `<|>`

Valid assignment targets:
- `x` - simple variable
- `x$field` - field extraction
- `x[[i]]` - subscripting
- `x[i]` - subsetting
- `names(x)` - replacement functions
- `attr(x, "foo")` - replacement functions
- `slot(x, "foo")` - S4 slots

**Solution:** Since we transform to `LHS <- RHS(LHS, ...)`, all valid assignment targets automatically work. The parser already validates LHS for `<-`.

**Test cases needed:**
```r
x <|> f()              # simple
x[1] <|> f()           # subscript
x[[1]] <|> f()         # extract
x$a <|> f()            # field
names(x) <|> f()       # replacement function
attr(x, "a") <|> f()   # replacement function
slot(x, "a") <|> f()   # S4 slot
```

### Issue #4: Operator Chaining - BANNED

**Decision:** Disallow chaining via `%nonassoc`

```r
x <|> f() <|> g()  # PARSE ERROR
```

**Rationale:**
- Almost certainly a user error
- Unclear semantics (doesn't match regular pipe behavior)
- Better to force explicit code

**Users should write:**
```r
x <|> f()
x <|> g()
# or
x <- x |> f() |> g()
```

**Implementation:** Use `%nonassoc PIPE_ASSIGN` in precedence declaration

### Issue #5: Placeholder Position - SIMPLIFIED

**Simplified placeholder support:**

**Supported:**
- Named argument only: `x <|> f(y = _)` ✓
- Forbidden in function name: `x <|> _()`  ✗

**Optional (if easy):**
- Extractor chains: `x <|> _$a[1]` ✓
- Include only if reusing code from `xxpipe()` is trivial

**Not supported:**
- Pipe-bind: `x <|> (y => expr)` ✗

**Implementation:** Simplified validation, reuse checkers from `xxpipe()` where applicable

### Issue #6: Memory Management

**Problem:** Parse tree duplication requires careful memory management

**Solution:**
- Use PROTECT/UNPROTECT for all duplicated SEXPs
- Use PRESERVE_SV/RELEASE_SV as done in xxpipe()
- Ensure no memory leaks

### Issue #7: Error Messages

Need clear error messages for:
- RHS is not a function call
- Pipe-bind syntax used (not supported)
- Placeholder in function name
- Placeholder not named
- Multiple placeholders

**Use existing error infrastructure from xxpipe()**

## Testing Strategy

### Unit Tests

Create tests in `tests/` directory:

```r
# Basic usage
x <- 5
x <|> sqrt()
stopifnot(identical(x, sqrt(5)))

# Subscripting
x <- c(1, 4, 9)
x[2] <|> sqrt()
stopifnot(identical(x, c(1, 2, 9)))

# Names
x <- c(a=1, b=2)
names(x) <|> toupper()
stopifnot(identical(names(x), c("A", "B")))

# Placeholder
x <- "hello"
x <|> sub("h", "H", x = _)
stopifnot(identical(x, "Hello"))

# Extractor chain
x <- list(a = c(1, 2, 3))
x <|> _$a[2]
# This should work like: x <- x$a[2]

# Errors
tryCatch(x <|> 5, error = function(e) message("OK: RHS not function"))
tryCatch(x <|> (y => y+1), error = function(e) message("OK: pipe-bind not supported"))
```

### Grammar Tests

Add to R's parser tests:
- Valid syntax parses correctly
- Invalid syntax produces expected errors
- Precedence is correct

## Implementation Checklist

- [ ] Add PIPE_ASSIGN token declaration
- [ ] Add precedence rule
- [ ] Implement lexer recognition of `<|>`
- [ ] Implement grammar rule
- [ ] Implement `xxpipeassign()` function
- [ ] Implement or locate `duplicate_sexp()` helper
- [ ] Add token name string
- [ ] Add error messages
- [ ] Write unit tests
- [ ] Test with complex LHS expressions
- [ ] Test placeholder functionality
- [ ] Test error conditions
- [ ] Document in R-lang.texi
- [ ] Add NEWS entry

## Files to Modify

1. `src/main/gram.y` - Main implementation
2. `tests/` - Add test file
3. `doc/manual/R-lang.texi` - Documentation (optional)
4. `NEWS` - User-visible change (optional)

## Decisions Made

1. **Chaining:** BANNED via `%nonassoc PIPE_ASSIGN`
   - `x <|> f() <|> g()` is a parse error

2. **Function call LHS:** Allowed (consistent with `<-`)
   - `f() <|> g()` evaluates f() twice (documented)

3. **Pipe-bind:** NOT supported
   - Simplifies implementation

4. **Extractor chains:** OPTIONAL
   - Include only if trivial to reuse from `xxpipe()`

5. **Syntax:** `<|>` (matches R's operator conventions)

## Summary

Simplified implementation based on user feedback:

**Core transform:** `LHS <|> RHS` → `LHS <- RHS(LHS, ...)`

**Simplifications:**
- ✗ No pipe-bind support
- ✗ Chaining banned via `%nonassoc`
- ? Extractor chains optional (include if easy)
- ✓ Simple placeholder support (named args only)

**Key insights:**
- Replacement functions (`names<-`, `[<-`) handle LHS evaluation correctly
- R's semantics already prevent double evaluation for common cases
- Parse tree duplication is simple for the transformed code

**Main implementation tasks:**
1. Lexer: 3-char lookahead for `<|>`
2. Token/grammar additions
3. `xxpipeassign()` function (simplified vs. `xxpipe()`)
4. Parse tree duplication helper
5. Non-associative precedence
6. Tests for all LHS types

The implementation is simpler than `|>` due to fewer features and clearer semantics.
