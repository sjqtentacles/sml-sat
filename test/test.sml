(* Tests for sml-sat: DPLL solver + DIMACS parser.

   Reference vectors:
     - {x},{~x}                  -> UNSAT
     - pigeonhole PHP(2,1)        -> UNSAT
     - all eight 3-variable clauses -> UNSAT
     - several SAT instances, every returned model checked with `verify`. *)

structure Tests =
struct
  open Harness
  structure S = Sat

  (* a satisfiable model must actually satisfy its CNF *)
  fun solvedAndVerified cnf =
    case S.solve cnf of
      NONE => false
    | SOME m => S.verify cnf m

  fun isUnsat cnf = not (S.isSat cnf) andalso S.solve cnf = NONE

  fun runAll () =
    let
      val () = section "numVars"
      val () = checkInt "empty"        (0, S.numVars [])
      val () = checkInt "single var"   (1, S.numVars [[1], [~1]])
      val () = checkInt "max over set" (4, S.numVars [[1, ~3], [2, 4], [~1]])

      val () = section "trivial SAT / UNSAT"
      val () = checkBool "unit clause is SAT"   (true,  S.isSat [[1]])
      val () = check     "unit model verifies"  (solvedAndVerified [[1]])
      val () = checkBool "{x},{~x} UNSAT"        (false, S.isSat [[1], [~1]])
      val () = check     "{x},{~x} solve NONE"   (isUnsat [[1], [~1]])
      val () = checkBool "empty CNF is SAT"      (true,  S.isSat [])
      val () = checkBool "model of empty CNF []" (true,  S.solve [] = SOME [])
      val () = checkBool "CNF w/ empty clause"   (false, S.isSat [[]])
      val () = check     "empty clause UNSAT"    (isUnsat [[1], []])

      val () = section "pigeonhole PHP(2,1) -> UNSAT"
      (* two pigeons, one hole: each pigeon in the hole, but not both. *)
      val php = [[1], [2], [~1, ~2]]
      val () = checkBool "php isSat"   (false, S.isSat php)
      val () = check     "php UNSAT"   (isUnsat php)

      val () = section "all eight 3-var clauses -> UNSAT"
      val all8 =
        [[ 1,  2,  3], [ 1,  2, ~3], [ 1, ~2,  3], [ 1, ~2, ~3],
         [~1,  2,  3], [~1,  2, ~3], [~1, ~2,  3], [~1, ~2, ~3]]
      val () = check     "all8 UNSAT" (isUnsat all8)
      (* dropping any one clause makes it SAT, with a verifiable model. *)
      val seven = List.tl all8
      val () = checkBool "drop one -> SAT" (true, S.isSat seven)
      val () = check     "drop one model verifies" (solvedAndVerified seven)

      val () = section "3-SAT satisfiable instances"
      val f1 = [[1, 2, ~3], [~1, 2, 3], [1, ~2, 3], [~1, ~2, ~3]]
      val () = checkBool "f1 SAT"          (true, S.isSat f1)
      val () = check     "f1 model verifies" (solvedAndVerified f1)
      val f2 = [[1, 2], [~2, 3], [~3, 4], [~1, 4], [2, ~4]]
      val () = checkBool "f2 SAT"          (true, S.isSat f2)
      val () = check     "f2 model verifies" (solvedAndVerified f2)
      val f3 = [[1, ~2, 3], [~1, 2], [~3], [2, 3]]
      val () = checkBool "f3 SAT"          (true, S.isSat f3)
      val () = check     "f3 model verifies" (solvedAndVerified f3)

      val () = section "pure-literal & unit propagation paths"
      (* var 3 appears only positively -> pure; chain of units. *)
      val pl = [[3], [3, 1], [~1, 2], [~2, 4], [3, 4]]
      val () = checkBool "pure/unit SAT"      (true, S.isSat pl)
      val () = check     "pure/unit verifies" (solvedAndVerified pl)
      (* forced chain: 1, then 2, then 3, then conflict with ~3 *)
      val chain = [[1], [~1, 2], [~2, 3], [~3]]
      val () = check     "forced chain UNSAT" (isUnsat chain)

      val () = section "model completeness over numVars"
      val m = valOf (S.solve f2)
      val () = checkInt  "model covers all vars" (4, List.length m)
      val () = check     "vars are 1..4"
                 (List.map #1 m = [1, 2, 3, 4])

      val () = section "verify: rejects wrong models"
      (* x1 must be true (unit), so x1=false fails. *)
      val () = checkBool "good model ok"   (true,  S.verify [[1]] [(1, true)])
      val () = checkBool "bad model fails"  (false, S.verify [[1]] [(1, false)])
      val () = checkBool "unassigned fails" (false, S.verify [[1]] [(2, true)])
      val () = checkBool "both clauses need cover"
                 (false, S.verify [[1], [2]] [(1, true), (2, false)])

      val () = section "DIMACS: parse"
      val d1 = "p cnf 2 2\n1 -2 0\n2 0\n"
      val () = check "basic parse" (S.parseDimacs d1 = [[1, ~2], [2]])
      val d2 = "c example\nc with comments\np cnf 3 2\n1 2 -3 0\n-1 0\n"
      val () = check "comments ignored" (S.parseDimacs d2 = [[1, 2, ~3], [~1]])
      val d3 = "p cnf 3 1\n1 2\n3 0\n"   (* clause spans two lines *)
      val () = check "clause spans lines" (S.parseDimacs d3 = [[1, 2, 3]])
      val d4 = "p cnf 1 2\n1 0\n-1 0\n%\n0\n"  (* trailing % stops parse *)
      val () = check "trailing % stops" (S.parseDimacs d4 = [[1], [~1]])
      val d5 = "p cnf 0 1\n0\n"          (* empty clause -> UNSAT *)
      val () = check "empty clause parse" (S.parseDimacs d5 = [[]])
      val () = checkRaises "bad token raises"
                 (fn () => S.parseDimacs "p cnf 1 1\n1 x 0\n")

      val () = section "DIMACS: out-of-range literal"
      (* An oversized literal must fail with the documented `Dimacs`
         exception on every compiler -- never `Overflow` (which MLton's
         fixed 32-bit `Int.fromString` raises past 2^31 while Poly/ML's
         63-bit int silently accepts it), so the behaviour is identical
         under MLton and Poly/ML. *)
      fun raisesDimacs thunk =
        (ignore (thunk ()); false)
          handle S.Dimacs _ => true | _ => false
      val () = check "12-digit literal -> Dimacs"
                 (raisesDimacs (fn () => S.parseDimacs "p cnf 1 1\n999999999999 0\n"))
      val () = check "2147483648 (2^31) -> Dimacs"
                 (raisesDimacs (fn () => S.parseDimacs "p cnf 1 1\n2147483648 0\n"))
      val () = check "negative overflow -> Dimacs"
                 (raisesDimacs (fn () => S.parseDimacs "p cnf 1 1\n-9999999999 0\n"))
      val () = check "in-range boundary literal ok"
                 (S.parseDimacs "p cnf 1 1\n2147483647 0\n" = [[2147483647]])

      val () = section "DIMACS: end-to-end solve"
      val () = check     "parsed UNSAT" (isUnsat (S.parseDimacs d1 @ [[~2]]))
      val () = check     "parsed php UNSAT"
                 (isUnsat (S.parseDimacs "c php\np cnf 2 3\n1 0\n2 0\n-1 -2 0\n"))
      val satTxt = "p cnf 4 5\n1 2 0\n-2 3 0\n-3 4 0\n-1 4 0\n2 -4 0\n"
      val () = check     "parsed SAT verifies" (solvedAndVerified (S.parseDimacs satTxt))

      val () = section "DIMACS: round trip"
      val cnf = [[1, ~2, 3], [~1, 2], [~3]]
      val () = check "toDimacs/parseDimacs round-trips"
                 (S.parseDimacs (S.toDimacs cnf) = cnf)
      val () = checkString "header reflects sizes"
                 ("p cnf 3 3", hd (String.fields (fn c => c = #"\n") (S.toDimacs cnf)))
    in
      Harness.run ()
    end

  val run = runAll
end
