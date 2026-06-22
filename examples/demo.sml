(* demo.sml - parse a DIMACS instance, solve it, verify the model; then show a
   classic UNSAT instance.  Deterministic: identical output on every run and
   both compilers. *)

structure S = Sat

fun showLit l = (if l < 0 then "-" else "") ^ Int.toString (abs l)
fun showClause c = "(" ^ String.concatWith " | " (List.map showLit c) ^ ")"
fun showCnf cnf = String.concatWith " & " (List.map showClause cnf)

fun showModel m =
  "[" ^ String.concatWith ", "
          (List.map (fn (v, b) => "x" ^ Int.toString v ^ "=" ^ Bool.toString b) m)
  ^ "]"

val dimacs =
  "c a small satisfiable 3-SAT instance\n\
  \p cnf 4 5\n\
  \1 2 0\n\
  \-2 3 0\n\
  \-3 4 0\n\
  \-1 4 0\n\
  \2 -4 0\n"

val () = print "Parsing DIMACS:\n"
val cnf = S.parseDimacs dimacs
val () = print ("  variables : " ^ Int.toString (S.numVars cnf) ^ "\n")
val () = print ("  clauses   : " ^ Int.toString (List.length cnf) ^ "\n")
val () = print ("  formula   : " ^ showCnf cnf ^ "\n")

val () = print "\nSolving with DPLL:\n"
val () =
  case S.solve cnf of
    NONE => print "  UNSAT\n"
  | SOME m =>
      (print ("  SAT, model = " ^ showModel m ^ "\n");
       print ("  verify    = " ^ Bool.toString (S.verify cnf m) ^ "\n"))

val () = print "\nPigeonhole PHP(2,1) -- two pigeons, one hole:\n"
val php = [[1], [2], [~1, ~2]]
val () = print ("  formula   : " ^ showCnf php ^ "\n")
val () = print ("  result    : "
                ^ (case S.solve php of NONE => "UNSAT" | SOME _ => "SAT") ^ "\n")
