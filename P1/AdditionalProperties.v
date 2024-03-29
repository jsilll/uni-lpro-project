(* ################################################################# *)
(** * Additional Properties 

      It might be a good idea to read the relevant book chapters/sections before or as you
      develop your solution. The properties below are discussed and some of them proved
      for the original Imp formulation.
*)

Set Warnings "-notation-overridden,-parsing,-deprecated-hint-without-locality".
From Coq Require Import Bool.Bool.
From Coq Require Import Init.Nat.
From Coq Require Import Arith.Arith.
From Coq Require Import Arith.EqNat. Import Nat.
From Coq Require Import Lia.
From Coq Require Import Lists.List. Import ListNotations.
From Coq Require Import Strings.String.
From FirstProject Require Import Maps Imp Interpreter RelationalEvaluation.
Set Default Goal Selector "!".


(**
  3.2. DONE: Prove all the properties below that are stated without proof.
             Add a succint comment before each property explaining the property in your own words.
*)

(* ################################################################# *)
(** * Property of the Step-Indexed Interpreter *)

(**
  Explanation:
  This property states that if the step indexed evaluator
  produces a successful output with some number of gas units,
  then if given more gas units it must reach the same output.
*)
Theorem ceval_step_more: forall i1 i2 st st' res c,
  i1 <= i2 ->
  ceval_step st c i1 = Some (st', res) ->
  ceval_step st c i2 = Some (st', res).
Proof.
  induction i1 as [| i1' ]; intros i2 st st' res c Hle Hceval.
  - (* i1 = 0 *)
    simpl in Hceval. inversion Hceval.
  - (* i1 = S i1' *) 
    destruct i2 as [| i2']; inversion Hle; subst.
    + (* i2 = 0 *)
      rewrite Hceval. reflexivity.
    + (* i2 = S i2' *)
    assert (Hle': i1' <= i2') by lia.
    destruct c.
      * (* Skip *)
        inversion Hceval. simpl. reflexivity.
      * (* Break *)
        inversion Hceval. simpl. reflexivity.
      * (* := *)
        inversion Hceval. simpl. reflexivity.
      * (* ; *)
        simpl in Hceval. simpl.
        destruct (ceval_step st c1 i1') eqn:Heqst1'o.
        -- (* Some *)
          destruct p. apply (IHi1' i2') in Heqst1'o; try assumption.
          rewrite Heqst1'o. destruct r.
          ++ (* SContinue *)
            apply (IHi1' i2') in Hceval; assumption.
          ++ (* SBreak *)
            assumption.
        -- (* None *)
          discriminate Hceval.
      * (* if *)
        simpl in Hceval. simpl.
        destruct (beval st b); apply IHi1'; assumption.
      * (* while *)
        simpl in Hceval. simpl.
        destruct (beval st b); try assumption.
        destruct (ceval_step st c i1') eqn:Heqst1'o.
        -- (* Some *)
          destruct p. apply (IHi1' i2') in Heqst1'o; try assumption.
          rewrite -> Heqst1'o. destruct r.
          ++ (* SContinue *)
            apply (IHi1' i2') in Hceval; assumption.
          ++ (* SBreak *)
            assumption.
        -- (* None *)
          discriminate Hceval.
Qed.

(* ################################################################# *)
(** * Relational vs. Step-Indexed Evaluation *)

(** As for arithmetic and boolean expressions, we'd hope that
    the two alternative definitions of evaluation would actually
    amount to the same thing in the end.  This section shows that this
    is the case. *)

(**
  Explanation:
  This property states that if the step indexed evaluator executes
  successfully, then the relation rules also arrive at the same conclusion.
  This proves one side of the double implication needed to prove equivalence
  between both semantics.
*)
Theorem ceval_step__ceval: forall c st st' res,
    (exists i, ceval_step st c i = Some (st', res)) ->
    st =[ c ]=> st' / res.
Proof.
  intros c st st' res H.
  inversion H as [i E].
  clear H.
  generalize dependent res.
  generalize dependent st'.
  generalize dependent st.
  generalize dependent c.
  induction i as [| i' ].
    - intros c st st' res H. discriminate.
    - intros c st st' res H. destruct c; simpl in H; inversion H; subst; clear H.
      -- apply E_Skip.
      -- apply E_Break.
      -- apply E_Asgn. reflexivity.
      -- destruct (ceval_step st c1 i') eqn:Heqr1.
        + destruct p.
          ++ destruct r.
            +++ apply E_SeqContinue with (s).
              * apply IHi'. rewrite Heqr1. reflexivity.
              * apply IHi'. rewrite H1. reflexivity.
            +++ inversion H1. apply E_SeqBreak. apply IHi'. rewrite Heqr1. rewrite H0. reflexivity.
        + discriminate.
      -- destruct (beval st b) eqn:Heqr.
        + apply E_IfTrue.
          ++ assumption.
          ++ apply IHi'. rewrite H1. reflexivity.
        + apply E_IfFalse.
          ++ assumption.
          ++ apply IHi'. rewrite H1. reflexivity.
      -- destruct (beval st b) eqn :Heqr.
        + destruct (ceval_step st c i') eqn:Heqr1.
          ++ destruct res.
            +++ destruct p. destruct r.
                * apply E_WhileTrueContinue with (s).
                  ** assumption.
                  ** apply IHi'. rewrite Heqr1. reflexivity.
                  ** apply IHi'. assumption. 
                * apply E_WhileTrueBreak.
                  ** assumption.
                  ** apply IHi'. rewrite Heqr1. inversion H1. reflexivity.
            +++ destruct p. destruct r.
              * apply IHi' in H1. apply IHi' in Heqr1. inversion H1.
              * discriminate.
          ++ discriminate. 
        + inversion H1. apply E_WhileFalse. rewrite <- H0. assumption.
Qed.

(** 
  DONE: For the following proof, you'll need [ceval_step_more] in a
  few places, as well as some basic facts about [<=] and [plus]. *)

(*
  Explanation:
  This property states that if the relation rules arrive at some conclusion, then, 
  for some gas value, the step indexed evaluator executes successfully and reaches a
  matching output.
  This proves the other side of the double implication needed to prove equivalence
  between both semantics. 
*)
Theorem ceval__ceval_step: forall c st st' res,
    st =[ c ]=> st' / res ->
    exists i, ceval_step st c i = Some (st', res).
Proof.
  intros. induction H.
  
  (* H comes from E_Break *)
  - exists 1. simpl. reflexivity.
  
  (* H comes from E_Skip *)
  - exists 1. simpl. reflexivity.
  
  (* H comes from E_Asgn *)
  - exists 1. simpl. rewrite H. reflexivity.
  
  (* H comes from E_SeqBreak *)
  - inversion IHceval as [i E]. exists (S i). simpl. rewrite E. reflexivity.
  
  (* H comes from E_SeqContinue *)
  - inversion IHceval1 as [i1 E1].
    inversion IHceval2 as [i2 E2].
    exists (S (max i1 i2)). simpl.
    apply ceval_step_more with (i2 := max i1 i2) in E1.
    + apply ceval_step_more with (i2 := max i1 i2) in E2.
      (* 'assumption.' instead of 'rewrite E2. reflexivity.' would also work *)
      * rewrite E1. rewrite E2. reflexivity. 
      * lia.
    + lia.
  
  (* H comes from E_IfTrue *)
  - inversion IHceval as [i E]. exists (S i). simpl. rewrite H. assumption.

  (* H comes from E_IfFalse *)
  - inversion IHceval as [i E]. exists (S i). simpl. rewrite H. assumption.
  
  (* H comes from E_WhileFalse *)
  - exists 1. simpl. rewrite H. reflexivity. 
  
  (* H comes from E_WhileTrueBreak *)
  - inversion IHceval as [i E]. exists (S i). simpl. rewrite H. rewrite E. reflexivity.
  
  (* H comes from E_WhileTrueContinue *)
  - inversion IHceval1 as [i1 E1].
    inversion IHceval2 as [i2 E2].
    exists (S (max i1 i2)). simpl.
    apply ceval_step_more with (i2 := max i1 i2) in E1.
    + rewrite H. apply ceval_step_more with (i2 := max i1 i2) in E2.
      (* 'assumption.' instead of 'rewrite E2. reflexivity.' would also work *)
      * rewrite E1. rewrite E2. reflexivity.
      * lia.
    + lia.
Qed. 

(* Note that with the above properties, we can say that both semantics are equivalent! *)

Theorem ceval_and_ceval_step_coincide: forall c st st' res,
    st =[ c ]=> st' / res
<-> exists i, ceval_step st c i = Some (st', res).
Proof.
intros c st st'.
split. 
 - apply ceval__ceval_step. 
 - apply ceval_step__ceval.
Qed.


(* ################################################################# *)
(** * Determinism of Evaluation Again *)

(** Using the fact that the relational and step-indexed definition of
  evaluation are the same, we can give a short proof that the
  evaluation _relation_ is deterministic. *)

(* DONE: Write/explain the following proof in natural language, 
         using your own words. *)  

(**
  Explanation:
  This theorem states that the evaluation relation is deterministic.
  
  Let st and c be some state and program, respectively. Then using the
  `ceval__ceval_step` theorem in both hypothesis we can conclude
  that for each one of them there exists some number i of gas units such that
  the step indexed evaluator executes successfully with st and c as inputs.

  Let i1 and i2 be such numbers. Then, using the `ceval_step_more` theorem,
  we are able to state that the result of both evaluations should remain the same
  when using i1 + i2 as the number of gas units. Since we have two equalities with the
  same left hand side we are able to conclude that their right hand side must be equal,
  that is 'Some (st1, res1) = Some (st2, res2)', which implies 'st1 = st2'. Qed.
*)
Theorem ceval_deterministic' : forall c st st1 st2 res1 res2,
   st =[ c ]=> st1 / res1 ->
   st =[ c ]=> st2 / res2 ->
   st1 = st2.
Proof.
  intros c st st1 st2 res1 res2 He1 He2.
  apply ceval__ceval_step in He1.
  apply ceval__ceval_step in He2.
  inversion He1 as [i1 E1].
  inversion He2 as [i2 E2].
  apply ceval_step_more with (i2 := i1 + i2) in E1.
   - apply ceval_step_more with (i2 := i1 + i2) in E2.
    -- rewrite E1 in E2. inversion E2. reflexivity.
    -- lia. 
   - lia.  
Qed.