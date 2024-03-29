(** * Imp: Simple Imperative Programs *)

(** Taken from the chapter Imp:
  https://softwarefoundations.cis.upenn.edu/lf-current/Imp.html

    It might be a good idea to read the chapter before or as you
    develop your solution.
*)

Set Warnings "-notation-overridden,-parsing,-deprecated-hint-without-locality".
From Coq Require Import Bool.Bool.
From Coq Require Import Init.Nat.
From Coq Require Import Arith.Arith.
From Coq Require Import Arith.EqNat. Import Nat.
From Coq Require Import Lia.
From Coq Require Import Lists.List. Import ListNotations.
From Coq Require Import Strings.String.
From FirstProject Require Import Maps Imp.
Set Default Goal Selector "!".

(** Next, we need to define the behavior of [break].  Informally,
    whenever [break] is executed in a sequence of commands, it stops
    the execution of that sequence and signals that the innermost
    enclosing loop should terminate.  (If there aren't any
    enclosing loops, then the whole program simply terminates.)  The
    final state should be the same as the one in which the [break]
    statement was executed.

    One important point is what to do when there are multiple loops
    enclosing a given [break]. In those cases, [break] should only
    terminate the _innermost_ loop. Thus, after executing the
    following...

       X := 0;
       Y := 1;
       while 0 <> Y do
         while true do
           break
         end;
         X := 1;
         Y := Y - 1
       end

    ... the value of [X] should be [1], and not [0].

    One way of expressing this behavior is to add another parameter to
    the evaluation relation that specifies whether evaluation of a
    command executes a [break] statement: *)

Inductive result : Type :=
  | SContinue
  | SBreak.

Reserved Notation "st '=[' c ']=>' st' '/' s"
     (at level 40, c custom com at level 99, st' constr at next level).

(** Intuitively, [st =[ c ]=> st' / s] means that, if [c] is started in
    state [st], then it terminates in state [st'] and either signals
    that the innermost surrounding loop (or the whole program) should
    exit immediately ([s = SBreak]) or that execution should continue
    normally ([s = SContinue]).

    The definition of the "[st =[ c ]=> st' / s]" relation is very
    similar to the one we gave above for the regular evaluation
    relation ([st =[ c ]=> st']) -- we just need to handle the
    termination signals appropriately:

    - If the command is [skip], then the state doesn't change and
      execution of any enclosing loop can continue normally.

    - If the command is [break], the state stays unchanged but we
      signal a [SBreak].

    - If the command is an assignment, then we update the binding for
      that variable in the state accordingly and signal that execution
      can continue normally.

    - If the command is of the form [if b then c1 else c2 end], then
      the state is updated as in the original semantics of Imp, except
      that we also propagate the signal from the execution of
      whichever branch was taken.

    - If the command is a sequence [c1 ; c2], we first execute
      [c1].  If this yields a [SBreak], we skip the execution of [c2]
      and propagate the [SBreak] signal to the surrounding context;
      the resulting state is the same as the one obtained by
      executing [c1] alone. Otherwise, we execute [c2] on the state
      obtained after executing [c1], and propagate the signal
      generated there.

    - Finally, for a loop of the form [while b do c end], the
      semantics is almost the same as before. The only difference is
      that, when [b] evaluates to true, we execute [c] and check the
      signal that it raises.  If that signal is [SContinue], then the
      execution proceeds as in the original semantics. Otherwise, we
      stop the execution of the loop, and the resulting state is the
      same as the one resulting from the execution of the current
      iteration.  In either case, since [break] only terminates the
      innermost loop, [while] signals [SContinue]. *)

(** 3.1. DONE: Based on the above description, complete the definition of the
               [ceval] relation. 
*)

Inductive ceval : com -> state -> result -> state -> Prop :=
  (* Break *)
  | E_Break : forall st,
      st =[ CBreak ]=> st / SBreak

  (* Skip *)
  | E_Skip : forall st,
      st =[ CSkip ]=> st / SContinue

  (* Assignment *)
  | E_Asgn : forall st a n x,
    aeval st a = n ->
     st =[ x := a ]=> (x !-> n ; st) / SContinue

  (* Sequence *)
  | E_SeqBreak : forall c1 c2 st st',
     st  =[ c1 ]=> st' / SBreak  ->
     st  =[ c1 ; c2 ]=> st' / SBreak
  | E_SeqContinue : forall c1 c2 st st' st'' s,
     st  =[ c1 ]=> st' / SContinue ->
     st' =[ c2 ]=> st'' / s ->
     st  =[ c1 ; c2 ]=> st'' / s

  (* If *)
  | E_IfTrue : forall st st' b c1 c2 s,
      beval st b = true ->
      st =[ c1 ]=> st' / s ->
      st =[ if b then c1 else c2 end]=> st' / s
  | E_IfFalse : forall st st' b c1 c2 s,
      beval st b = false ->
      st =[ c2 ]=> st' / s ->
      st =[ if b then c1 else c2 end]=> st' / s

  (* While *)
  | E_WhileFalse : forall b st c,
      beval st b = false ->
      st =[ while b do c end ]=> st / SContinue
  | E_WhileTrueBreak : forall st st' b c,
      beval st b = true ->
      st  =[ c ]=> st' / SBreak ->
      st  =[ while b do c end ]=> st' / SContinue
  | E_WhileTrueContinue : forall st st' st'' b c,
      beval st b = true ->
      st  =[ c ]=> st' / SContinue ->
      st' =[ while b do c end ]=> st'' / SContinue ->
      st  =[ while b do c end ]=> st'' / SContinue
      
  where "st '=[' c ']=>' st' '/' s" := (ceval c st s st').

(** 
  3.2. DONE: Prove the following six properties of your definition of [ceval].
             Note that your semantics needs to satisfy these properties: if any of 
             these properties becomes unprovable, you should revise your definition of `ceval`. 
             Add a succint comment before each property explaining the property in your own words.
*)

(**
  Explanation:
  This property states that if a break command is 
  encountered, no matter what the following program 
  instructions are, the resulting state remains unchanged.
*)
Theorem break_ignore : forall c st st' s,
     st =[ break; c ]=> st' / s ->
     st = st'.
Proof.
  intros. inversion H.
  - inversion H5. reflexivity. 
  - inversion H2.
Qed.

(**
  Explanation:
  This property states that the resulting signal of
  evaluating a while loop is never a break signal.
  This happens because all break instructions within
  'c' only break the innermost loop.
*)
Theorem while_continue : forall b c st st' s,
  st =[ while b do c end ]=> st' / s ->
  s = SContinue.
Proof.
  intros. inversion H; reflexivity. 
Qed.

(*
  Explanation:
  This theorem states that when the execution of the body of a
  while loop signals SBreak, then the resulting state of the loop is the state
  that resulted from that execution, and the loop signals SContinue.
*)
Theorem while_stops_on_break : forall b c st st',
  beval st b = true ->
  st =[ c ]=> st' / SBreak ->
  st =[ while b do c end ]=> st' / SContinue.
Proof.
  intros. apply E_WhileTrueBreak; assumption.
Qed.


(*
  Explanation:
  This theorem states that when both commands of a sequence signal SContinue,
  then the resulting state of the sequence is is the state that resulted
  from executing both commands, and the signal of the sequence is SContinue.
  (This is a particular case of the E_SeqContinue rule, in which the 's' variable
  is instanciated to SContinue)
*)
Theorem seq_continue : forall c1 c2 st st' st'',
  st =[ c1 ]=> st' / SContinue ->
  st' =[ c2 ]=> st'' / SContinue ->
  st =[ c1 ; c2 ]=> st'' / SContinue.
Proof.
  intros. apply E_SeqContinue with (st' := st'); assumption. 
Qed.


(*
  Explanation: 
  This theorem states that when the execution of a command c1 signals SBreak, then a sequential
  composition starting with c1 produces the same state and it also signals SBreak.
*)
Theorem seq_stops_on_break : forall c1 c2 st st',
  st =[ c1 ]=> st' / SBreak ->
  st =[ c1 ; c2 ]=> st' / SBreak.
Proof.
  intros. apply E_SeqBreak. assumption. 
Qed.

(*
Explanation:
This theorem states that when the execution of a loop stops in a state that still satisfies its
condition, then there must exist some reachable break command that breaks said loop.
*)
Theorem while_break_true : forall b c st st',
  st =[ while b do c end ]=> st' / SContinue ->
  beval st' b = true ->
  exists st'', st'' =[ c ]=> st' / SBreak.
Proof.
  intros. remember (<{while b do c end}>) as loop. induction H; inversion Heqloop; subst.
  
  (* H comes from E_WhileFalse (contradiction) *)
  - rewrite H in H0. discriminate.
  
  (* H comes from E_WhileTrueBreak *)
  - exists st. assumption.

  (* H comes from E_WhileTrueContinue *)
  - apply IHceval2; assumption.
Qed.