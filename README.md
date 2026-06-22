# sml-sat

[![CI](https://github.com/sjqtentacles/sml-sat/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-sat/actions/workflows/ci.yml)

A compact **DPLL SAT solver** with a **DIMACS CNF parser**, in pure Standard ML.

A CNF formula is an `int list list`: an outer list of clauses, each an inner
list of literals. A literal is a non-zero `int` whose magnitude names a variable
(`1..n`) and whose sign is the polarity — `3` is the variable, `-3` its negation.

No dependencies, no FFI, no threads, no clock, no randomness: the same inputs
always produce the same outputs under **MLton** and **Poly/ML**. The search is
deterministic.

- **DPLL** with **unit propagation** and **pure-literal elimination**, plus
  chronological backtracking (binary branch on the first unassigned literal).
- **`verify`** independently checks any returned model against the clauses.
- **DIMACS** parsing handles `c` comment lines, the `p cnf V C` header,
  clauses that span lines, and an optional trailing `%`.

> **Scope.** This is classic DPLL — complete and sufficient for the instances
> here. Clause learning (CDCL) is intentionally out of scope. It is also
> **dependency-free** by design: there is no external parser dependency.

## API

```sml
structure Sat : sig
  type cnf = int list list
  type assignment = (int * bool) list
  exception Dimacs of string

  val numVars     : cnf -> int
  val solve       : cnf -> assignment option   (* model complete over 1..numVars *)
  val isSat       : cnf -> bool
  val verify      : cnf -> assignment -> bool
  val parseDimacs : string -> cnf
  val toDimacs    : cnf -> string
end
```

`solve` returns a **complete** assignment over variables `1..numVars` (any
variable the search left free is reported as `true`), so a returned model can be
handed straight back to `verify`.

## Example

```sml
val cnf = Sat.parseDimacs "p cnf 3 2\n1 2 -3 0\n-1 0\n"   (* [[1,2,~3],[~1]] *)
val SOME m = Sat.solve cnf
val true   = Sat.verify cnf m

val false  = Sat.isSat [[1], [~1]]                        (* {x} & {~x} -> UNSAT *)
val false  = Sat.isSat [[1], [2], [~1, ~2]]               (* PHP(2,1)   -> UNSAT *)
```

Running [`examples/demo.sml`](examples/demo.sml) with `make example` prints:

```
Parsing DIMACS:
  variables : 4
  clauses   : 5
  formula   : (1 | 2) & (-2 | 3) & (-3 | 4) & (-1 | 4) & (2 | -4)

Solving with DPLL:
  SAT, model = [x1=true, x2=true, x3=true, x4=true]
  verify    = true

Pigeonhole PHP(2,1) -- two pigeons, one hole:
  formula   : (1) & (2) & (-1 | -2)
  result    : UNSAT
```

## Build & test

Requires [MLton](http://mlton.org/) and/or [Poly/ML](https://polyml.org/).

```sh
make test        # build + run the suite under MLton
make test-poly   # run the suite under Poly/ML
make all-tests   # both
make example     # build + run the demo
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-sat
smlpkg sync
```

Reference `lib/github.com/sjqtentacles/sml-sat/sat.mlb` from your own `.mlb`
(MLton / MLKit), or feed `sources.mlb` to `tools/polybuild` (Poly/ML).

## Layout

```
sml.pkg                                   smlpkg manifest
Makefile                                  MLton + Poly/ML targets
.github/workflows/ci.yml                  CI: MLton + Poly/ML
lib/github.com/sjqtentacles/sml-sat/
  sat.sig    SAT signature
  sat.sml    DPLL + DIMACS implementation
  sources.mlb / sat.mlb
examples/
  demo.sml   DIMACS parse + solve + verify walkthrough
test/
  harness.sml / test.sml                  42 reference checks
  entry.sml / main.sml
tools/polybuild                           Poly/ML build wrapper
```

## Tests

42 deterministic checks: trivial SAT/UNSAT, the contradiction `{x} & {~x}`, the
pigeonhole instance `PHP(2,1)`, the full set of eight 3-variable clauses (UNSAT)
plus every 7-clause subset (SAT), several satisfiable 3-SAT formulas whose
returned models are re-checked with `verify`, unit-propagation and pure-literal
paths, model completeness over `numVars`, `verify` rejecting wrong/partial
models, and DIMACS parsing (comments, multi-line clauses, trailing `%`, empty
clauses, bad-token errors) with a `toDimacs`/`parseDimacs` round trip. Run
`make all-tests` to verify identical output under both compilers.

## License

MIT. See [LICENSE](LICENSE).
