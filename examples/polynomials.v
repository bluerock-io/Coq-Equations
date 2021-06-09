(** printing elimination %\coqdoctac{elimination}% *)
(** printing noconf %\coqdoctac{noconf}% *)
(** printing simp %\coqdoctac{simp}% *)
(** printing by %\coqdockw{by}% *)
(** printing rec %\coqdockw{rec}% *)
(** printing Coq %\Coq{}% *)
(** printing funelim %\coqdoctac{funelim}% *)
(** printing Derive %\coqdockw{Derive}% *)
(** printing Signature %\coqdocclass{Signature}% *)
(** printing Subterm %\coqdocclass{Subterm}% *)
(** printing NoConfusion %\coqdocclass{NoConfusion}% *)
(** * Polynomials

  Polynomials and a reflexive tactic for solving boolean goals (using
  heyting or classical boolean algebra).  Original version by Rafael
  Bocquet, 2016. Updated to use Equations for all definitions by M. Sozeau,
  2016-2017. If running this interactively you can ignore the printing
  and hide directives which are just used to instruct coqdoc. *)
(* begin hide *)
Require Import Program.Basics Program.Tactics.
From Equations Require Import Equations.
Require Import ZArith Lia.
Require Import Psatz.
Require Import NPeano.
Require Import Nat.
Require Import Coq.Vectors.VectorDef.

Set Keyed Unification.

Notation vector := Vector.t.
Arguments nil {A}.
Arguments cons {A} _ {n}.

Derive Signature for vector eq.
Coercion Bool.Is_true : bool >-> Sortclass.

Notation pack := Signature.signature_pack.

Lemma Is_true_irrel (b : bool) (p q : b) : p = q.
Proof.
  destruct b. destruct p, q. reflexivity.
  destruct p.
Defined.
Hint Resolve Is_true_irrel : core.
Check Zpos.
Check Zneg.
Check positive.
Check NoConfusion.
About Signature.
Check Signature.signature_pack.
(* end hide *)

(** We start with a simple definition deciding if some integer is equal
    to [0] or not. Integers are encoded using an inductive type [Z]
    with three constructors [Z0], [Zpos] and [Zneg], the latter two
    taking [positive] numbers as arguments. There is a single
    representant of [0] which we discriminate here. The second clause
    actually captures both the [Zpos] and [Zneg] constructors.  *)

Equations IsNZ (z : Z) : bool :=
  IsNZ Z0 := false; IsNZ _ := true.

(** The specification of this test is that it returns true iff the variable is indeed
    different from [0] w.r.t. the standard Leibniz equality. We elide a simple proof
    by case analysis. Note that we use an implicit coercion from [bool] to [Prop] here,
    as is usual when doing boolean reflection. *)

Lemma IsNZ_spec z : IsNZ z <-> (z <> 0)%Z.
Proof.
  funelim (IsNZ z); unfold not; split; intros;
    (discriminate || contradiction || constructor).
Qed.

(** *** Multivariate polynomials

   Using an indexed inductive type, we ensure that polynomials of
   %$\mathbb{Z}[(X_i)_{i \in \mathbb{N}}]$% have a unique
   representation.  The first index indicates that the polynom is
   null. The second index gives the number of free variables. *)

Inductive poly : bool -> nat -> Type :=
| poly_z : poly true O
| poly_c (z : Z) : IsNZ z -> poly false O
| poly_l {n b} (Q : poly b n) : poly b (S n)
| poly_s {n b} (P : poly b n) (Q : poly false (S n)) :
    poly false (S n).

(**
- [poly_z] represents the null polynomial.
- [poly_c c] represents the constant polynomial [c] where [c] is non-zero (i.e. has a proof of [IsNZ c]).
- [poly_l n Q] represents the injection of [Q], a
  polynomial on [n] variables, as a polynomial on [n+1] variables.
- Finally, [poly_s P Q : poly _ (S n)] represents $P + X_n * Q$
  where [P] cannot mention the variable $X_n$ but [Q] can mention
  the variables up to and including $X_n$, and the multiplication is
  not trivial as [Q] is non-null.

These indices enforce a canonical
representation by ordering the multiplications of the variables.  A
similar encoding is actually used in the [ring] tactic of [Coq]. *)

Derive Signature NoConfusion NoConfusionHom for poly.
Derive Subterm for poly.

(** In addition to the usual eliminators of the inductive type
  generated by [Coq], we automatically derive a few constructions on
  this [poly] datatype, and the [mono] datatype that follows, 
  that will be used by the [Equations] command:

- Its [Signature]: as described earlier %(\S \ref{sec:deppat})%, this is
  the packing of a polynomial with its two indices, a boolean and a
  natural number in this case.
- Its [NoConfusion] property used to
  simplify equalities between constructors of the [poly] type 
  (equation %\ref{eqn:noconf}%).
- Finally, its [Subterm] relation, to be used when performing
  well-founded recursion on [poly]. *)

(** *** Monomials

  Monomials represent parts of polynoms, and one can compute the
  coefficient constant by which each monomial is multiplied in a given
  polynom. Again the index of a [mono] gives the number of its free variables. *)

Inductive mono : nat -> Type :=
| mono_z : mono O
| mono_l : forall {n}, mono n -> mono (S n)
| mono_s : forall {n}, mono (S n) -> mono (S n).

Derive Signature NoConfusion NoConfusionHom Subterm for mono.

(** Our first interesting definition computes the coefficient in [Z] by which
    a monomial [m] is multiplied in a polynomial [p]. *)

Equations get_coef {n} (m : mono n) {b} (p : poly b n) : Z by wf (pack m) mono_subterm :=
get_coef mono_z     poly_z       := 0%Z;
get_coef mono_z     (poly_c z _) := z;
get_coef (mono_l m) (poly_l p)   := get_coef m p;
get_coef (mono_l m) (poly_s p _) := get_coef m p;
get_coef (mono_s m) (poly_l _)   := 0%Z;
get_coef (mono_s m) (poly_s p1 p2) := get_coef m p2.

(** The definition can be done using either the usual structural
  recursion of [Coq] or well-founded recursion. If we use structural
  recursion, the guardness check might not be able to verify the
  automatically generated proof that the function respects its graph, as
  it involves too much rewriting due to dependent pattern-matching. We
  could prove it using a dependent induction instead of using the raw
  fixpoint combinator as the recursion is on direct subterms of the
  monomial, but in general it could be arbitrarily complicated, so we
  present a version allowing deep pattern-matching and recursion. Note
  that this means we lose the definitional behavior of [get_coef] during
  proofs on open terms, but this can advantageously be replaced using
  explicit [rewrite] calls, providing much more control over
  simplification than the reduction tactics, especially in presence of
  recursive functions. The [get_coef] function still uses no axioms, 
  so it can be used to compute as part of a reflexive tactic for example.

  We want to do recursion on the (dependent) [m : mono n] argument,
  using the derived [mono_subterm] relation, which expects an element in
  the signature of [mono], [{ n : nat & mono n }], so we use [pack m] to
  lift [m] into its signature type ([pack] is just an abbreviation for
  the [signature_pack] overloaded constant defined in %\S
  \ref{sec:deppat}%).

  The rest of the definition is standard: to fetch a monomial
  coefficient, we simultaneously pattern-match on the monomial and
  polynomial. Note that many cases are impossible due to the invariants
  enforced in [poly] and [mono]. For example [mono_z] can only match
  polynomials built from [poly_z] or [poly_c], etc. *)

(** *** Two detailed proofs

  The monomial decomposition is actually a complete characterization
  of a polynomial: two polynomials with the same coefficients for every
  monomial are the same. *)

(** To show this, we need a lemma that shows that every non-null polynomial,
    has a monomial with non-null coefficient:
    this proof is done by dependent induction on the polynomial [p].
    Note that the index of [p] rules out the [poly_z] case. *)

Lemma poly_nz {n} (p : poly false n) : exists m, IsNZ (get_coef m p).
Proof with (autorewrite with get_coef; auto).
  intros. depind p.
  exists mono_z...
  destruct IHp. exists (mono_l x)...
  destruct IHp2. exists (mono_s x)...
Qed.

Notation " ( x ; p ) " := (existT _ x p).

Theorem get_coef_eq {n} b1 b2
  (p1 : poly b1 n) (p2 : poly b2 n) :
  (forall (m : mono n), get_coef m p1 = get_coef m p2) ->
  (b1 ; p1) = (b2 ; p2) :> { null : _ & poly null n}.
Proof with (simp get_coef in *; auto).

  (** Throughout the proof, we use the [simp] tactic defined by
      %\Equations% which is a wrapper around [autorewrite] using the hint
      database associated to the constant [get_coef]: the database
      contains the defining equations of [get_coef] as rewrite rules
      that can be used to simplify calls to [get_coef] in the goal. *)
  
intros Hcoef.
induction p1 as [ | z Hz | n b p1 | n b p1 IHp q1 IHq ]
  in b2, p2, Hcoef |- *;
[dependent elimination p2 as [poly_z | poly_c z i] |
 dependent elimination p2 as [poly_z | poly_c z' i'] |
 dependent elimination p2 as
     [@poly_l n b' p2 | @poly_s n b' p2 q2] ..].
  all:(intros; try rename n0 into n; auto;
      try (specialize (Hcoef mono_z); simp get_coef in Hcoef; subst z;
           (elim i || elim Hz ||
            ltac:(repeat f_equal; auto)); fail)).
  - specialize (IHp1 _ p2). forward IHp1. intro m.
    specialize (Hcoef (mono_l m))... clear Hcoef.

    (** We first do an induction on [p1] and then eliminate (dependently)
        [p2], the first two branches need to consider variable-closed [p2]s
        while the next two branches have [p2 : poly _ (S n)], hence the [poly_l] 
        and [poly_s] patterns. The elided rest of the tactic solves simple subgoals. 
      
      We now focus on the case for [poly_l] on both sides. 
      After some simplifications of the induction hypothesis using 
      the [Hcoef] hypothesis, we get to the following goal:
[[
  (b, b' : bool) (n : nat) (p1 : poly b n) (p2 : poly b' n)
  IHp1 : (b; p1) = (b'; p2)
  ============================
  (b; poly_l p1) = (b'; poly_l p2)
]]

  The [IHp1] hypothesis, as a general equality between dependent 
  pairs can again be eliminated dependently to substitute [b'] by 
  [b] and [p2] by [p1] simultaneously, using 
  [dependent elimination IHp1 as [eq_refl]], leaving us with 
  a trivial subgoal. *)
(* begin hide *)
    dependent elimination IHp1 as [eq_refl].
    reflexivity.
  - destruct (poly_nz q2) as [m HNZ].
    specialize (Hcoef (mono_s m))...
    rewrite <- Hcoef in HNZ; elim HNZ.

  - destruct (poly_nz q1) as [m HNZ].
    specialize (Hcoef (mono_s m))...
    rewrite Hcoef in HNZ; elim HNZ.
    
  - forward (IHq _ q2).
    intro m. specialize (Hcoef (mono_s m))...
    apply f_equal.
    forward (IHp _ p2).
    intro. specialize (Hcoef (mono_l m))...
    depelim IHp.
    now depelim IHq.
Qed.
(* end hide *)

(** The next step is to give an evaluation semantics to polynomials.
    We program [eval p v] where [v] is a valuation in [Z] for all the
    variables in [p : poly _ n]. *)

Equations eval {n} {b} (p : poly b n) (v : Vector.t Z n) : Z :=
  eval poly_z         nil           := 0%Z;
  eval (poly_c z _)   nil           := z;
  eval (poly_l p)     (cons _ xs)   := eval p xs;
  eval (poly_s p1 p2) (cons y ys) :=
    (eval p1 ys + y * eval p2 (cons y ys))%Z.

(** It is quite clear that two equal polynomials should have the
    same value for any valuation. To show this, we first need to prove
    that evaluating a null polynomial always computes to [0], whichever
    valuation is used. *)
(* begin hide *)
Check eval.
Lemma poly_nz_eval' : forall {n},
                          (forall (p : poly false n), exists v, IsNZ (eval p v)) ->
                          (forall (p : poly false (S n)),
                           exists v, forall m, exists x,
                                 IsNZ x /\
                                 (Z.abs (x * eval p (Vector.cons x v)) > Z.abs m)%Z).
Proof with (simp eval).
  depind p.
  - destruct (H p) as [v Hv].
    exists v; intros; exists (1 + Z.abs m)%Z...
    rewrite IsNZ_spec in Hv |- *. nia.
  - destruct (IHp2 H) as [v Hv]; exists v; intros.
    destruct (Hv (Z.abs (eval p1 v) + Z.abs m)%Z) as [x [Hx0 Hx1]]; exists x...
    split; auto. rewrite IsNZ_spec in Hx0.
    nia.
Qed.

Lemma poly_nz_eval : forall {n},
    (forall (p : poly false n), exists v, IsNZ (eval p v))
    /\ (forall (p : poly false (S n)),
           exists v, forall m, exists x,
                 IsNZ x /\
                 (Z.abs (x * eval p (Vector.cons x v)) > Z.abs m)%Z).
Proof with (autorewrite with eval; auto using poly_nz_eval').
  depind n; match goal with
            | [ |- ?P /\ ?Q ] => assert (HP : P); [|split;[auto|]]
            end...
  depelim p; exists Vector.nil...
  - destruct IHn as [IHn1 IHn2]; depelim p.
    + destruct (IHn1 p) as [v Hv]; exists (Vector.cons 0%Z v)...
    + destruct (IHn2 p2) as [v Hv].
      destruct (Hv (eval p1 v)) as [x [_ Hx]].
      exists (Vector.cons x v)...
      rewrite IsNZ_spec; nia.
Qed.
(* end hide *)
(** This is a typical case where the proof directly follows the definition
  of [eval]. Instead of redoing the same case splits and induction that
  the function performs, we can directly appeal to its elimination
  principle using the [funelim] tactic. *)

Lemma poly_z_eval {n} (p : poly true n) v : eval p v = 0%Z.
Proof.
  funelim (eval p v); [ reflexivity | assumption ].
Qed.

(** This leaves us with two goals as the [true] index in [p] implies
  that the [poly_c] and [poly_s] clauses do not need to be considered.
  We have to show [0 = 0] for the case [p = poly_z] and [eval q v = 0]
  for the [poly_l] recursive constructor, in which case the conclusion
  directly follows from the induction hypothesis correspondinng to the
  recursive call. The second subgoal is hence discharged with an
  [assumption] call.

  Addition is defined on two polynomials with the same number of variables and returns
  a (possibly null) polynomial with the same number of variables.
  We define an injection function to constructs objects in the dependent pair type
  [{b : bool & poly b n}]. *)

Definition apoly {n b} := existT (fun b => poly b n) b.

(** The definition shows the [with] feature of Equations, allowing to
    add a nested pattern-matching while defining the function, here in
    one case to inject an integer into a polynomial and in the
    [poly_s], [poly_s] case to inspect a recursive call. *)

Notation " x .1 " := (projT1 x) (at level 3, format "x .1").
Notation " x .2 " := (projT2 x) (at level 3, format "x .2").

Equations plus {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 n) : { b : bool & poly b n } :=
  plus poly_z        poly_z          := apoly poly_z;
  plus poly_z        (poly_c y ny)   := apoly (poly_c y ny);
  plus (poly_c x nx) poly_z          := apoly (poly_c x nx);
  plus (poly_c x nx) (poly_c y ny)   with (x + y)%Z => {
                 | Z0 => apoly poly_z ;
                 | Zpos z' => apoly (poly_c (Zpos z') I) ;
                 | Zneg z' => apoly (poly_c (Zneg z') I) };
  plus (poly_l p1)    (poly_l p2)    := apoly (poly_l (plus p1 p2).2);
  plus (poly_l p1)    (poly_s p2 q2) := apoly (poly_s (plus p1 p2).2 q2);
  plus (poly_s p1 q1) (poly_l p2)    := apoly (poly_s (plus p1 p2).2 q1);

  plus (poly_s p1 q1) (poly_s p2 q2) with plus q1 q2 => {
       | (false ; q3) => apoly (poly_s (plus p1 p2).2 q3);
       | (true  ; _)  => apoly (poly_l (plus p1 p2).2) }.

(** The functional elimination principle can be derived all the same
    for [plus], allowing us to make quick work of the proof that it
    is a morphism for evaluation: *)

Lemma plus_eval : forall {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 n) v,
    (eval p1 v + eval p2 v)%Z = eval (plus p1 p2).2 v.
Proof with (simp plus eval; auto with zarith).
  Ltac X := (simp plus eval; auto with zarith).
    intros until p2.
    let f := constr:(fun_elim (f:=@plus)) in apply f; intros; depelim v; X; try rewrite <- H; X.
  - rewrite Heq in Hind.
    specialize (Hind (Vector.cons h v)).
    rewrite poly_z_eval in Hind. nia.
  - rewrite Heq in Hind. rewrite <- Hind. nia.
Qed.
Hint Rewrite <- @plus_eval : eval.

(** We skip the rest of the operations definition, [poly_mult], [poly_neg] and
    [poly_substract]. *)

Equations poly_neg {n} {b} (p : poly b n) : poly b n :=
  poly_neg poly_z := poly_z;
  poly_neg (poly_c (Z.pos a) p) := poly_c (Z.neg a) p;
  poly_neg (poly_c (Z.neg a) p) := poly_c (Z.pos a) p;
  poly_neg (poly_l p) := poly_l (poly_neg p);
  poly_neg (poly_s p q) := poly_s (poly_neg p) (poly_neg q).

Lemma neg_eval : forall {n} {b1} (p1 : poly b1 n) v,
    (- eval p1 v)%Z = eval (poly_neg p1) v.
Proof.
  Ltac XX := (autorewrite with poly_neg plus eval; auto with zarith).
  depind p1; depelim v; XX. destruct z; depelim i; XX.
  rewrite <- IHp1_1; rewrite <- IHp1_2; nia.
Qed.
Hint Rewrite <- @neg_eval : eval.

(** Equality can be decided using the difference of polynoms *)
Lemma poly_diff_z_eq : forall {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 n),
    (plus p1 (poly_neg p2)).1 = true ->
    (_ ; p1) = (_; p2) :> { null : bool & poly null n }.
Proof.
  intros.
  depind p1; depelim p2; auto;
    try (autorewrite with poly_neg plus in H; discriminate; fail).
  - destruct z; destruct i; autorewrite with poly_neg plus in *; discriminate.
  - f_equal; destruct z as [ | z | z], z0 as [ | z0 | z0 ]; depelim i; depelim i0; autorewrite with poly_neg plus in H.
    assert (z = z0).
    remember (Z.pos z + Z.neg z0)%Z as z1; destruct z1; try discriminate; simpl in H; nia.
    subst; auto.
    remember (Z.pos z + Z.pos z0)%Z as z1; destruct z1; try discriminate.
    remember (Z.neg z + Z.neg z0)%Z as z1; destruct z1; try discriminate.
    assert (z = z0).
    remember (Z.neg z + Z.pos z0)%Z as z1; destruct z1; try discriminate; simpl in H; nia.
    subst; auto.
  - autorewrite with poly_neg plus in H.
    specialize (IHp1 _ p2 H).
    depelim IHp1. auto.
  - autorewrite with poly_neg plus in H.
    specialize (IHp1_1 _ p2_1); specialize (IHp1_2 _ p2_2).
    remember (plus p1_2 (poly_neg p2_2)) as P; remember (plus p1_1 (poly_neg p2_1)) as Q.
    destruct P as [bP P]; destruct Q as [bQ Q].
    destruct bP; destruct bQ; simpl in H; try rewrite <- HeqQ in H; try discriminate.
    specialize (IHp1_1 eq_refl); specialize (IHp1_2 eq_refl).
    depelim IHp1_1; try depelim IHp1_2; auto.
Qed.

(**
 *** Two polynomials with the same values are syntacically equal. 
 This is shown using [poly_nz_eval]: the difference of two polynomials with the same values is null.
 Then use [poly_diff_z_eq]
 *)
Theorem poly_eval_eq : forall {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 n),
    (forall v, eval p1 v = eval p2 v) ->
    (b1 ; p1) = (b2; p2) :> { b : bool & poly b n}.
Proof.
  intros.
  remember (plus p1 (poly_neg p2)) as P; destruct P as [b P]; destruct b.
  - apply poly_diff_z_eq; inversion HeqP; auto.
  - exfalso.
    destruct (@poly_nz_eval n) as [H0 _]; destruct (H0 P) as [v H1].
    assert (eval P v = eval (plus p1 (poly_neg p2)).2 v); [inversion HeqP; auto|].
    rewrite H2 in H1; autorewrite with eval in H1; rewrite (H v) in H1.
    rewrite IsNZ_spec in H1.
    nia.
Qed.

(**
 *** Multiplication of polynomials

  This definition is a bit more laborious as there are inductive cases to treat on the second argument:
  it is not a simple structurally recursive definition.
 *)

(** The [poly_l_or_s] definition is a smart constructor to construct
    [p + X * q] when [q] can be null. *)

Equations poly_l_or_s {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 (S n)) :
  {b : bool & poly b (S n)} :=
poly_l_or_s p1 (b2 := true) p2 := apoly (poly_l p1);
poly_l_or_s p1 (b2 := false) p2 := apoly (poly_s p1 p2).
                                        
Lemma poly_l_or_s_eval : forall {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 (S n)) h v,
    eval (poly_l_or_s p1 p2).2 (Vector.cons h v) =
    (eval p1 v + h * eval p2 (Vector.cons h v))%Z.
Proof.
  intros.
  funelim (poly_l_or_s p1 p2); simp eval; trivial. rewrite poly_z_eval. nia.
Qed.
Hint Rewrite @poly_l_or_s_eval : eval.

(* [mult (poly_l p) q = mult_l q (mult p)] *)

Equations mult_l {n} {b2} (p2 : poly b2 (S n)) (m : forall {b2} (p2 : poly b2 n), { b : bool & poly b n }) :
  { b : bool & poly b (S n) } :=
  mult_l (poly_l p2) m := apoly (poly_l (m _ p2).2);
  mult_l (poly_s p1 p2) m := poly_l_or_s (m _ p1).2 (mult_l p2 m).2.

(* [mult (poly_s p1 p2) q = mult_s q (mult p1) (mult p2)] *)

Equations mult_s {n} {b2} (p2 : poly b2 (S n))
     (m1 : forall {b2} (p2 : poly b2 n), { b : bool & poly b n })
     (m2 : forall {b2} (p2 : poly b2 (S n)), { b : bool & poly b (S n) }) :
    { b : bool & poly b (S n) } :=
  mult_s (poly_l p1) m1 m2 := poly_l_or_s (m1 _ p1).2 (m2 _ (poly_l p1)).2;
  mult_s (poly_s p2 q2) m1 m2 :=
    poly_l_or_s (m1 _ p2).2
                (plus (m2 _ (poly_l p2)).2 (mult_s q2 m1 m2).2).2.

(** Finally, the multiplication definition. This relies on the
   guard condition being able to unfold the definitions of [mult_l] and [mult_s] to
   see that multiplication is well-guarded. *)

Equations mult n b1 (p1 : poly b1 n) b2 (p2 : poly b2 n) : { b : bool & poly b n } :=
    mult ?(0) ?(true) poly_z        b2 _ := apoly poly_z;
    mult ?(0) ?(false) (poly_c x nx) ?(true) poly_z := apoly poly_z;
    mult ?(0) ?(false) (poly_c x nx) ?(false) (poly_c y ny) :=
    match (x * y)%Z with
      | Z0 => apoly poly_z
      | Zpos z' => apoly (poly_c (Zpos z') I)
      | Zneg z' => apoly (poly_c (Zneg z') I)
    end;
    mult ?(S n) ?(b) (@poly_l n b p1)    b2 q := mult_l q (mult _ _ p1);
    mult ?(S n) ?(false) (@poly_s n b p1 q1) b2 q := mult_s q (mult _ _ p1) (mult _ _ q1).
Arguments mult {n} {b1} p1 {b2} p2.

(** The proof that multiplication is a morphism for evaluation works as usual by induction,
    using previously proved lemma to get equations in [Z] that the [nia] tactic can handle. *)

Lemma mult_eval : forall {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 n) v,
    (eval p1 v * eval p2 v)%Z = eval (mult p1 p2).2 v.
Proof with (autorewrite with mult mult_l mult_s eval; auto with zarith).
  Ltac Y := (autorewrite with mult mult_l mult_s eval; auto with zarith).
  depind p1; try (depind p2; intros; depelim v; Y; simpl; Y; fail).
  depind p2; intros; depelim v; Y; simpl; Y; destruct (z * z0)%Z; simpl...
  - assert (mult_l_eval : forall {b2} (q : poly b2 (S n)) v h,
               eval (mult_l q (@mult _ _ p1)).2 (Vector.cons h v) =
               (eval q (Vector.cons h v) * eval p1 v)%Z).
    + depind q; intros; Y;
        rewrite <- IHp1...
      rewrite IHq2; auto; nia.
    + intros; depelim v; Y; simpl; Y; rewrite mult_l_eval...
  - assert (mult_s_eval :
              forall {b2} (q : poly b2 (S n)) v h,
                let mp := mult_s q (@mult _ _ p1_1) (@mult _ _ p1_2) in
                  eval mp.2 (Vector.cons h v) =
                  (eval q (Vector.cons h v) * (eval p1_1 v + h * eval p1_2 (Vector.cons h v)))%Z).
    + depind q; intros; Y; simpl; Y.
      rewrite <- IHp1_1, <- IHp1_2; Y; nia.
      rewrite <- IHp1_1. rewrite IHq2, <- IHp1_2; auto; Y; nia.
    + intros; depelim v; Y; simpl; Y; rewrite mult_s_eval...
Qed.
Hint Rewrite <- @mult_eval : eval.
(** ** Boolean formulas

  Armed with these definitions, we can define a reflexive tactic that
  solves boolean tautologies using a translation into polynomials on [Z].
  We start with the syntax of our formulas, including variables of some type
  [A], constants, conjunction disjunction and negation: *)

Inductive formula {A} :=
| f_var : A -> formula
| f_const : bool -> formula
| f_and : formula -> formula -> formula
| f_or : formula -> formula -> formula
| f_not : formula -> formula.

(** The have a straightforward evaluation semantics to booleans, assuming
    an interpretation of the variables into booleans. *)

Equations eval_formula {A} (v : A -> bool) (f : @formula A) : bool :=
  eval_formula f (f_var v)   := f v;
  eval_formula f (f_const b) := b;
  eval_formula f (f_and a b) := andb (eval_formula f a) (eval_formula f b);
  eval_formula f (f_or a b)  := orb (eval_formula f a) (eval_formula f b);
  eval_formula f (f_not v)   := negb (eval_formula f v).

(** [close_formula] allows to obtain a formula with a fixed finite number of free variables from
   a formula with with variables in [nat]. *)
Definition close_formula : @formula nat -> { n : nat & forall m, m >= n -> @formula (Fin.t m) }.
Proof.
  intro f; depind f.
  - unshelve eapply (S a ; _); intros m p; apply f_var.
    apply @Fin.of_nat_lt with (p := a). lia.
  - exact (O ; (fun _ _ => f_const b)).
  - destruct IHf1 as [n1 e1]; destruct IHf2 as [n2 e2].
    apply (existT _ (max n1 n2)); intros m p; apply f_and; [apply e1|apply e2]; nia.
  - destruct IHf1 as [n1 e1]; destruct IHf2 as [n2 e2].
    apply (existT _ (max n1 n2)); intros m p; apply f_or; [apply e1|apply e2]; nia.
  - destruct IHf as [n e].
    apply (existT _ n); intros m p; apply f_not; apply e; nia.
Defined.
  
Definition close_formulas (f1 f2 : @formula nat) :
  { n : nat & (@formula (Fin.t n) * @formula (Fin.t n))%type }.
Proof.
  destruct (close_formula f1) as [n1 e1]; destruct (close_formula f2) as [n2 e2].
  apply (existT _ (max n1 n2)); apply pair; [apply e1|apply e2]; nia.
Defined.

(** Definitions of constant 0 [poly_zero] and 1 [poly_one] polynomials along with variable polynomials
    [poly_var] and corresponding evaluation lemmas *)

Fixpoint poly_zero {n} : poly true n :=
  match n with
  | O   => poly_z
  | S m => poly_l poly_zero
  end.
Lemma zero_eval : forall n v, 0%Z = eval (@poly_zero n) v.
Proof. intros; rewrite poly_z_eval; auto. Qed.
Hint Rewrite <- @zero_eval : eval.

Fixpoint poly_one {n} : poly false n :=
  match n with
  | O   => poly_c 1%Z I
  | S m => poly_l poly_one
  end.
Lemma one_eval : forall n v, 1%Z = eval (@poly_one n) v.
Proof. depind n; depelim v; intros; simpl; autorewrite with eval; auto. Qed.  
Hint Rewrite <- @one_eval : eval.

(** We define an injection of variables represented as indices in [Fin.t n] into
    non-null polynoms of [n] variables: *)

Equations poly_var {n} (f : Fin.t n) : poly false n :=
  poly_var Fin.F1     := poly_s poly_zero poly_one;
  poly_var (Fin.FS f) := poly_l (poly_var f).

(** We can show that evaluation of the corresponding polynomial corresponds to
    simply fetching the value at the index in the valuation. *)

Lemma var_eval : forall n f v, Vector.nth v f = eval (@poly_var n f) v.
Proof with autorewrite with poly_var eval in *; simpl; auto with zarith.
  induction f; depelim v; intros...
Qed.
Hint Rewrite <- @var_eval : eval.

(** Finally, we explain our interpretation of formulas as polynomials: *)

Equations poly_of_formula {n} (f : @formula (Fin.t n)) : { b : bool & poly b n } :=
  poly_of_formula (f_var v)       := apoly (poly_var v);
  poly_of_formula (f_const false) := apoly poly_zero;
  poly_of_formula (f_const true)  := apoly poly_one;
  poly_of_formula (f_not a)       := plus poly_one (poly_neg (poly_of_formula a).2);
  poly_of_formula (f_and a b)     := mult (poly_of_formula a).2 (poly_of_formula b).2;
  poly_of_formula (f_or a b)      := plus (poly_of_formula a).2
                                          (plus (poly_of_formula b).2
          (poly_neg (mult (poly_of_formula a).2 (poly_of_formula b).2).2)).2.

(** The central theorem is that evaluating the formula in some valuation
    is the same as evaluating the translated polynomial. *)

Theorem poly_of_formula_eval :
  forall {n} (f : @formula (Fin.t n)) (v : Vector.t bool n),
    (if eval_formula (Vector.nth v) f then 1%Z else 0%Z) =
    eval (poly_of_formula f).2 (Vector.map (fun x : bool => if x then 1%Z else 0%Z) v).
(* begin hide *)
Proof.
  intros. funelim (poly_of_formula f); intros;
    autorewrite with eval_formula poly_of_formula eval in *; trivial.
  - erewrite Vector.nth_map; auto.
  - rewrite <- H, <- H0; destruct (eval_formula (Vector.nth v) a); destruct (eval_formula (Vector.nth v) b); auto.
  - rewrite <- H, <- H0; destruct (eval_formula (Vector.nth v) a); destruct (eval_formula (Vector.nth v) b); auto.
  - rewrite <- H; destruct (eval_formula (Vector.nth v) a); auto.
Qed.
(* end hide *)

(** From this, we can derive that two boolean formulas are equivalent if
    the translated polynomials are themselves _syntactically_ equal,
    thanks to their canonical representation. *)

Lemma correctness_heyting : forall {n} (f1 f2 : @formula (Fin.t n)),
    poly_of_formula f1 = poly_of_formula f2 ->
    forall v, eval_formula (Vector.nth v) f1 = eval_formula (Vector.nth v) f2.
Proof.
  intros n f1 f2 H v.
  assert (H1 := poly_of_formula_eval f1 v); assert (H2 := poly_of_formula_eval f2 v).
  remember (eval_formula (Vector.nth v) f1) as b1; remember (eval_formula (Vector.nth v) f2) as b2.
  rewrite H in H1; rewrite <- H1 in H2.
  destruct b1; destruct b2; simpl in *; (discriminate || auto).
Qed.

(** *** Completeness

  For which theory do we have completeness? If you were attentive you might
  have guessed that the encodings of disjunction and conjunction are only
  complete for heyting boolean algebras but not classical boolean algebra,
  where negation is involutive.

  One can avoid this problem by doing a reduction transformation on polynomials.
  The interested reader can look at the development for that part.
  Completeness can be derived for the reducing version of the translation.
 *)

Equations reduce_aux {n} {b1} (p1 : poly b1 n) {b2} (p2 : poly b2 (S n)) : { b : bool & poly b (S n) } :=
reduce_aux p1 (poly_l p2) := poly_l_or_s p1 (poly_l p2);
reduce_aux p1 (poly_s p2_1 p2_2) := poly_l_or_s p1 (plus (poly_l p2_1) p2_2).2.

Equations reduce {n} {b} (p : poly b n) : { b : bool & poly b n } :=
  reduce poly_z       := apoly poly_z;
  reduce (poly_c x y) := apoly (poly_c x y);
  reduce (poly_l p)   := apoly (poly_l (reduce p).2);
  reduce (poly_s p q) := reduce_aux (reduce p).2 (reduce q).2.
  
Theorem reduce_eval :
  forall {n} {b} (p : poly b n) (v : Vector.t bool n),
    eval p (Vector.map (fun x : bool => if x then 1%Z else 0%Z) v) =
    eval (reduce p).2 (Vector.map (fun x : bool => if x then 1%Z else 0%Z) v).
Proof.
  Ltac YY := autorewrite with reduce reduce_aux eval; auto.
  depind p; intros; depelim v; YY.
  - rewrite IHp1, (IHp2 (Vector.cons h v)).
    remember (reduce p2) as P.
    destruct P as [bP P]. simpl. depelim P; simpl; YY.
    destruct h; nia.
Qed.
   
Inductive is_reduced : forall {b} {n}, poly b n -> Prop :=
| is_reduced_z : is_reduced poly_z
| is_reduced_c : forall {z} {i}, is_reduced (poly_c z i)
| is_reduced_l : forall {b} {n} (p : poly b n), is_reduced p -> is_reduced (poly_l p)
| is_reduced_s : forall {b1} {n} (p : poly b1 n) (q : poly false n),
    is_reduced p -> is_reduced q -> is_reduced (poly_s p (poly_l q))
.
Derive Signature for is_reduced.

Lemma is_reduced_compat_plus : forall {n} {b1} (p1 : poly b1 n) (Hp1 : is_reduced p1)
                                      {b2} (p2 : poly b2 n) (Hp2 : is_reduced p2),
    is_reduced (plus p1 p2).2.
Proof.
  intros.
  depind Hp1; depelim Hp2; autorewrite with plus; unfold apoly; try constructor; auto.
  remember (z+z0)%Z as Z; destruct Z; constructor.
  specialize (IHHp1_2 _ q0 Hp2_2).
  remember (plus q q0) as Q; destruct Q as [bQ Q].
  destruct bQ; simpl. constructor; auto. constructor; auto.
Qed.

Lemma is_reduced_compat_neg : forall {n} {b1} (p1 : poly b1 n) (Hp1 : is_reduced p1),
    is_reduced (poly_neg p1).
Proof.
  intros. depind Hp1; try destruct z, i; autorewrite with poly_neg; try constructor; auto.
Qed.

Lemma is_reduced_ok : forall {b} {n} (p : poly b n), is_reduced (reduce p).2.
Proof.
  depind p; try constructor; auto.
  autorewrite with reduce reduce_aux.
  remember (reduce p2) as P2; destruct P2 as [bP2 P2]; depelim P2.
  destruct bP2; simpl. constructor. auto. constructor; auto. depelim IHp2. auto.

  depelim IHp2. autorewrite with reduce_aux plus. unfold apoly. simpl.
  assert (R := is_reduced_compat_plus _ IHp2_1 _ IHp2_2).
  remember (plus P2_1 q) as P3; destruct P3 as [bP3 P3]. simpl.
  simpl in *.
  destruct bP3; simpl; constructor; auto.
Qed.

Lemma red_ok : forall {n} {b} (p : poly b n),
    is_reduced p ->
    (forall v, eval p (Vector.map (fun x : bool => if x then 1%Z else 0%Z) v) = 0%Z) ->
    b = true.
Proof.
  intros n b p Hp H; depind Hp.
  - auto.
  - specialize (H Vector.nil); autorewrite with eval in H; destruct z, i; discriminate.
  - apply IHHp. intro v. specialize (H (Vector.cons false v)). autorewrite with eval in H. auto.
  - assert (b1 = true).
    + apply IHHp1. intro v. specialize (H (Vector.cons false v)). autorewrite with eval in H. simpl in H. rewrite Z.add_0_r in H. auto.
    + subst. apply IHHp2.
      intro v. specialize (H (Vector.cons true v)). simpl in H. autorewrite with eval in H. rewrite poly_z_eval in H. nia.
Qed.

(** We have completeness for this form: *)

Lemma correctness_classical : forall {n} (f1 f2 : @formula (Fin.t n)),
    reduce (poly_of_formula f1).2 = reduce (poly_of_formula f2).2 <->
    forall v, eval_formula (Vector.nth v) f1 = eval_formula (Vector.nth v) f2.
Proof.
  intros n f1 f2; split.
  - intros H v.
    assert (H1 := poly_of_formula_eval f1 v); assert (H2 := poly_of_formula_eval f2 v).
    rewrite reduce_eval in H1; rewrite reduce_eval in H2.
    remember (eval_formula (Vector.nth v) f1) as b1; remember (eval_formula (Vector.nth v) f2) as b2.
    rewrite H in H1; rewrite <- H1 in H2.
    destruct b1; destruct b2; simpl in *; (discriminate || auto).
  - intros.
    assert ((plus (reduce (poly_of_formula f1).2).2
                  (poly_neg (reduce (poly_of_formula f2).2).2)).1 = true).
    + apply red_ok with (p := (plus (reduce (poly_of_formula f1).2).2
                                    (poly_neg (reduce (poly_of_formula f2).2).2)).2).
      * auto using is_reduced_compat_plus, is_reduced_ok, is_reduced_compat_neg.
      * intro; autorewrite with eval.
        assert (H1 := poly_of_formula_eval f1 v); assert (H2 := poly_of_formula_eval f2 v).
        rewrite <- !reduce_eval, <- H1, <- H2, (H v); nia.
    + apply poly_diff_z_eq in H0.
      remember (reduce (poly_of_formula f1).2) as P1; destruct P1 as [bP1 P1].
      remember (reduce (poly_of_formula f2).2) as P2; destruct P2 as [bP2 P2].
      destruct bP1; destruct bP2; auto; simpl in H0; depelim H0; auto.
Qed.

(** One can check that all definitions here are axiom free, and only the proofs
    which depend on unfolding lemmas use the [functional_extensionality_dep] axiom. *)

(** *** Reflexive tactic

  From this it is possible to derive a tactic for checking equivalence of boolean
  formulas. We skip the standard reification machinery and check on a few examples
  that indeed our tactic computes. *)

Ltac list_add a l :=
    let rec aux a l n :=
        match l with
          | nil => constr:((n, cons a l))
          | cons a _ => constr:((n, l))
          | cons ?x ?l =>
            match aux a l (S n) with (?n, ?l) => constr:((n, cons x l)) end
        end in
    aux a l 0.

Ltac vector_of_list l :=
  match l with
  | nil => constr:(Vector.nil)
  | cons ?x ?xs => constr:(Vector.cons x xs)
  end.

(** Reify boolean formulas with variables in [nat] *)

Ltac read_formula f l :=
  match f with
  | true => constr:((@f_const nat true, l))
  | false => constr:((@f_const nat false, l))
  | orb ?x ?y => match read_formula x l with (?x', ?l') =>
                    match read_formula y l' with (?y', ?l'') => constr:((f_or x' y', l''))
                    end end
  | andb ?x ?y => match read_formula x l with (?x', ?l') =>
                     match read_formula y l' with (?y', ?l'') => constr:((f_and x' y', l''))
                     end end
  | negb ?x => match read_formula x l with (?x', ?l') => constr:((f_not x', l')) end
  | _ => match list_add f l with (?n, ?l') => constr:((f_var n, l')) end
  end.

Ltac read_formulas x y :=
  match read_formula x (@nil bool) with (?x', ?l) =>
  match read_formula y l with (?y', ?l') => constr:(((x', y'), l'))
  end end.

(** The final reflexive tactic, taking either of the correctness lemmas as argument. *)

Ltac bool_tauto_with f :=
  intros;
  match goal with
  | [ |- ?x = ?y ] =>
    match read_formulas x y with
    | ((?x', ?y'), ?l) =>
      let ln := fresh "l" in
      let xyn := fresh "xy" in
      let nn := fresh "n" in
      let xn := fresh "x" in
      let yn := fresh "y" in
      match vector_of_list l with ?lv => pose (ln := lv) end;
      pose (xyn := close_formulas x' y');
      pose (n := xyn.1); pose (xn := fst xyn.2); pose (yn := snd xyn.2);
      cbv in xyn, n, xn, yn;
      assert (H : eval_formula (Vector.nth ln) xn = eval_formula (Vector.nth ln) yn);
      [ apply f; vm_compute; reflexivity
      | exact H
      ]
    end
  end.

(** Examples *)

Goal forall a b, andb a b = andb b a.
  bool_tauto_with @correctness_heyting.
Qed.
Goal forall a b, andb (negb a) (negb b) = negb (orb a b).
  bool_tauto_with @correctness_heyting.
Qed.
Goal forall a b, orb (negb a) (negb b) = negb (andb a b).
  bool_tauto_with @correctness_heyting.
Qed.

Example neg_involutive: forall a, orb (negb a) a = true.
Fail bool_tauto_with @correctness_heyting.
bool_tauto_with @correctness_classical.
Qed.
