(* sat.sml - DPLL SAT solver + DIMACS parser.

   Scope: classic DPLL (Davis-Putnam-Logemann-Loveland) with unit propagation
   and pure-literal elimination, plus chronological backtracking via a binary
   branch on the first unassigned literal.  No clause learning / CDCL: DPLL is
   complete and sufficient for the small instances exercised here.  The state
   is a purely functional assignment (an int->bool assoc list); clauses are
   re-simplified against it at each node, which keeps the code obviously
   correct at the cost of speed (fine for these sizes). *)

structure Sat :> SAT =
struct
  type cnf = int list list
  type assignment = (int * bool) list

  exception Dimacs of string

  fun lookup (_ : int) [] = NONE
    | lookup v ((k, b) :: rest) = if k = v then SOME b else lookup v rest

  fun numVars cnf =
    List.foldl
      (fn (cl, m) => List.foldl (fn (l, m) => Int.max (m, abs l)) m cl)
      0 cnf

  (* ---------------------------------------------------------------- *)
  (* DPLL search.  Returns SOME partial-assignment if satisfiable.    *)

  datatype simp = Sat | Keep of int list

  fun dpllSearch clauses =
    let
      fun litTrue assign l =
        case lookup (abs l) assign of SOME b => (l > 0) = b | NONE => false
      fun litFalse assign l =
        case lookup (abs l) assign of SOME b => (l > 0) <> b | NONE => false

      (* Simplify every clause under `assign`:
           - drop satisfied clauses,
           - drop falsified literals,
           - report a conflict (NONE) if a clause becomes empty.
         Returned clauses contain only currently-unassigned literals. *)
      fun simplify assign =
        let
          fun simpC c =
            if List.exists (litTrue assign) c then Sat
            else Keep (List.filter (fn l => not (litFalse assign l)) c)
          fun go [] acc = SOME (List.rev acc)
            | go (c :: cs) acc =
                case simpC c of
                  Sat => go cs acc
                | Keep [] => NONE
                | Keep ls => go cs (ls :: acc)
        in go clauses [] end

      fun findUnit cs =
        case List.find (fn c => case c of [_] => true | _ => false) cs of
          SOME [l] => SOME l
        | _ => NONE

      (* a literal is pure if its negation never occurs in the remaining set. *)
      fun findPure cs =
        let val lits = List.concat cs
        in List.find (fn l => not (List.exists (fn m => m = ~l) lits)) lits end

      fun dpll assign =
        case simplify assign of
          NONE => NONE
        | SOME [] => SOME assign
        | SOME cs =>
            (case findUnit cs of
               SOME l => dpll ((abs l, l > 0) :: assign)
             | NONE =>
                 case findPure cs of
                   SOME l => dpll ((abs l, l > 0) :: assign)
                 | NONE =>
                     let val v = abs (List.hd (List.hd cs))
                     in case dpll ((v, true) :: assign) of
                          SOME a => SOME a
                        | NONE => dpll ((v, false) :: assign)
                     end)
    in dpll [] end

  fun isSat cnf = Option.isSome (dpllSearch cnf)

  fun solve cnf =
    case dpllSearch cnf of
      NONE => NONE
    | SOME assign =>
        let
          val n = numVars cnf
          val full =
            List.tabulate (n, fn i =>
              let val v = i + 1
              in (v, case lookup v assign of SOME b => b | NONE => true) end)
        in SOME full end

  fun verify cnf assign =
    let
      fun litTrue l =
        case lookup (abs l) assign of SOME b => (l > 0) = b | NONE => false
    in List.all (fn c => List.exists litTrue c) cnf end

  (* ---------------------------------------------------------------- *)
  (* DIMACS                                                            *)

  fun isWS c = c = #" " orelse c = #"\t" orelse c = #"\r" orelse c = #"\n"

  fun parseDimacs text =
    let
      val lines = String.fields (fn c => c = #"\n") text
      fun firstNonWS line =
        List.find (fn c => not (isWS c)) (String.explode line)
      fun dataToks line =
        case firstNonWS line of
          NONE => []                       (* blank line *)
        | SOME #"c" => []                  (* comment *)
        | SOME #"p" => []                  (* header *)
        | _ => String.tokens isWS line
      val toks = List.concat (List.map dataToks lines)
      fun untilPct [] = []
        | untilPct (t :: ts) = if t = "%" then [] else t :: untilPct ts
      (* Parse via `IntInf` and bounds-check into the fixed 32-bit range.
         `Int.fromString` raises `Overflow` past 2^31 on MLton (32-bit int)
         but not on Poly/ML (63-bit int); routing through `IntInf` and
         rejecting out-of-range values keeps the parser total and identical
         on both compilers. *)
      fun parseInt t =
        case IntInf.fromString t of
          SOME n =>
            if n >= ~2147483648 andalso n <= 2147483647
            then IntInf.toInt n
            else raise Dimacs ("integer literal out of range: " ^ t)
        | NONE => raise Dimacs ("not an integer literal: " ^ t)
      val ints = List.map parseInt (untilPct toks)
      fun build [] cur acc =
            if List.null cur then List.rev acc
            else List.rev (List.rev cur :: acc)
        | build (0 :: rest) cur acc = build rest [] (List.rev cur :: acc)
        | build (x :: rest) cur acc = build rest (x :: cur) acc
    in build ints [] [] end

  fun toDimacs cnf =
    let
      val n = numVars cnf
      val c = List.length cnf
      val header = "p cnf " ^ Int.toString n ^ " " ^ Int.toString c ^ "\n"
      val body =
        String.concat
          (List.map
             (fn cl =>
                String.concatWith " " (List.map Int.toString cl) ^ " 0\n")
             cnf)
    in header ^ body end
end
