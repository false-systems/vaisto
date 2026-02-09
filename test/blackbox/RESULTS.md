# vaistoc CLI — Black-Box Test Results

**Date:** 2026-02-09
**Version:** 0.1.0
**Total:** 62 cases | **Pass:** 53 | **Fail:** 5 | **Bugs:** 4

## Confirmed Bugs (4)

### BUG-1: `--eval ""` leaks UndefinedFunctionError stacktrace (NEG-010)

**Input:** `vaistoc --eval ""`
**Expected:** Clean error message like `error: empty expression`
**Actual:**
```
** (UndefinedFunctionError) function VaistoEval.main/0 is undefined
    VaistoEval.main()
    (vaisto 0.1.0) lib/vaisto/cli.ex:184: Vaisto.CLI.eval_code/2
```
**Severity:** Medium — exposes internal module names and file paths to user
**Fix:** Check for empty/whitespace-only input before compiling eval code

### BUG-2: `--eval "   "` leaks same stacktrace (ABN-010)

**Input:** `vaistoc --eval "   "`
**Expected:** Clean error or empty result
**Actual:** Same UndefinedFunctionError as BUG-1
**Severity:** Medium — same root cause as BUG-1
**Fix:** Same as BUG-1: trim and validate input before eval

### BUG-3: `--eval "(/ 1 0)"` leaks ArithmeticError stacktrace (ABN-001)

**Input:** `vaistoc --eval "(/ 1 0)"`
**Expected:** Clean error like `error: division by zero`
**Actual:**
```
** (ArithmeticError) bad argument in arithmetic expression
    VaistoEval.main/0
    (vaisto 0.1.0) lib/vaisto/cli.ex:184: Vaisto.CLI.eval_code/2
```
**Severity:** Medium — runtime error not caught at compile time or eval boundary
**Fix:** Wrap eval execution in try/rescue, format runtime errors cleanly

### BUG-4: Compile to read-only directory leaks File.Error stacktrace (ABN-006)

**Input:** `vaistoc examples/math.va -o /read-only-dir/Math.beam`
**Expected:** Clean error like `error: cannot write to /read-only-dir/Math.beam: permission denied`
**Actual:**
```
** (File.Error) could not write to file "...": permission denied
    (elixir 1.19.5) lib/file.ex:1407: File.write!/3
    (vaisto 0.1.0) lib/vaisto/cli.ex:159: Vaisto.CLI.compile_file/3
```
**Severity:** Medium — uses `File.write!` (raising) instead of `File.write` (returning)
**Fix:** Use `File.write/3` and handle `{:error, reason}` with formatted message

## Design Issues (3)

### ISSUE-1: `eval ")"` silently succeeds with atom output (NEG-011)

**Input:** `vaistoc --eval ")"`
**Expected:** Parse error
**Actual:** Outputs `:")"` with exit code 0
**Assessment:** The parser treats `)` as an atom. Debatable whether this is a bug or intended, but likely surprising to users.

### ISSUE-2: Non-.va files compile without warning (NEG-013)

**Input:** `vaistoc somefile.txt` (containing `"hello"`)
**Expected:** Error or warning about non-.va extension
**Actual:** Compiles successfully to `.beam`
**Assessment:** The compiler doesn't validate file extensions. Consider at least a warning.

### ISSUE-3: Package names with digits are rejected (POS-026)

**Input:** `vaistoc init bb-test-pkg-026`
**Expected:** Success (looks like valid kebab-case)
**Actual:** `error: package name must be lowercase kebab-case`
**Assessment:** The kebab-case validator rejects digits. This is a design choice, not necessarily a bug, but the error message doesn't mention the no-digits constraint. If digits are intentionally disallowed, the error message should say so.

## Test Environment Failures (2)

- **SYS-001, SYS-003:** Failed because `init` was called in `/tmp` with a name containing digits (same root cause as ISSUE-3).

## Coverage Summary

| Category | Cases | Pass | Fail | Bug |
|----------|-------|------|------|-----|
| Positive | 27 | 26 | 1 | 0 |
| Negative | 13 | 10 | 2 | 1 |
| System | 4 | 2 | 2 | 0 |
| Integration | 3 | 3 | 0 | 0 |
| Performance | 3 | 3 | 0 | 0 |
| Load | 2 | 2 | 0 | 0 |
| Abnormal | 10 | 7 | 0 | 3 |

## Recommendations

1. **Highest priority:** Wrap `eval_code/2` in try/rescue to catch runtime errors (fixes BUG-1, BUG-2, BUG-3)
2. **High priority:** Replace `File.write!/3` with `File.write/3` + error handling in `compile_file/3` (fixes BUG-4)
3. **Medium:** Add input validation for empty/whitespace-only eval expressions
4. **Low:** Consider validating `.va` extension or emitting a warning
5. **Low:** Clarify in error message that package names cannot contain digits (if intentional)

## Running the Suite

```bash
# From project root:
test/blackbox/runner.sh
```
