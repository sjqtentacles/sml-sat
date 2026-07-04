(* sat.sig

   A small DPLL SAT solver with a DIMACS CNF parser, in pure Standard ML.

   A formula in conjunctive normal form (CNF) is represented as an
   `int list list`: an outer list of clauses, each an inner list of literals.
   A literal is a non-zero int whose magnitude names a variable (1..n) and
   whose sign gives polarity: positive means the variable, negative means its
   negation. `0` never appears in a literal (it terminates clauses in DIMACS).

   An `assignment` maps variable indices to booleans as `(int * bool) list`.
   `solve` returns a *complete* assignment over variables 1..numVars (any
   variable the search left free is reported as `true`), so a returned model
   can be fed straight back into `verify`.

   No FFI, threads, clock or randomness: the same inputs always produce the
   same outputs under MLton and Poly/ML. The search is deterministic. *)

signature SAT =
sig
  type cnf = int list list
  type assignment = (int * bool) list

  exception Dimacs of string

  (* number of distinct variables: the largest |literal| (0 if none). *)
  val numVars : cnf -> int

  (* DPLL with unit propagation and pure-literal elimination.
     SOME model if satisfiable (model complete over 1..numVars), else NONE. *)
  val solve : cnf -> assignment option

  (* satisfiability without materialising a model. *)
  val isSat : cnf -> bool

  (* does the assignment satisfy every clause?  A literal whose variable is
     unassigned counts as false, so a partial assignment must still cover
     each clause with an assigned, true literal. *)
  val verify : cnf -> assignment -> bool

  (* Parse DIMACS CNF text.  `c ...` comment lines and the `p cnf V C` header
     are ignored; clauses are whitespace-separated literals terminated by 0 and
     may span lines; an optional trailing `%` stops parsing.  Raises `Dimacs`
     on a non-integer token or a literal outside the fixed 32-bit `int` range
     (so parsing behaves identically under MLton and Poly/ML, never raising
     `Overflow`). *)
  val parseDimacs : string -> cnf

  (* Render a CNF back to DIMACS text (with a `p cnf V C` header). *)
  val toDimacs : cnf -> string
end
