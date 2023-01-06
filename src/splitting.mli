(**********************************************************************)
(* Equations                                                          *)
(* Copyright (c) 2009-2021 Matthieu Sozeau <matthieu.sozeau@inria.fr> *)
(**********************************************************************)
(* This file is distributed under the terms of the                    *)
(* GNU Lesser General Public License Version 2.1                      *)
(**********************************************************************)

open Environ
open Names
open Syntax
open EConstr
open Equations_common
open Context_map

(** Programs and splitting trees *)

(** Splitting trees *)

type path_component = Id.t

type path = path_component list

val path_id : ?unfold:bool -> path -> Id.t

module PathOT :
  sig
    type t = path
    val compare : t -> t -> int
  end
module PathMap : CSig.MapS with type key = PathOT.t

type wf_rec = {
  wf_rec_term : constr;
  wf_rec_functional : constr option;
  wf_rec_arg : constr;
  wf_rec_rel : constr }

type struct_rec = {
  struct_rec_arg : Syntax.rec_annot;
  struct_rec_protos : int;
}

type rec_node =
  | WfRec of wf_rec
  | StructRec of struct_rec

type rec_info =
  { rec_prob : context_map;
    rec_lets : rel_context;
    rec_sign : rel_context;
    rec_arity : constr;
    rec_args : int;
    rec_node : rec_node }

type splitting =
    Compute of context_map * where_clause list * types * splitting_rhs
  | Split of context_map * int * types * splitting option array
  | Mapping of context_map * splitting
  | Refined of context_map * refined_node * splitting

and where_clause =
  { where_program : program;
    where_program_orig : program_info;
    where_program_args : constr list; (* In original context, de Bruijn only *)
    where_path : path;
    where_orig : path;
    where_context_length : int; (* Length of enclosing context, including fixpoint prototype if any *)
    where_type : types }

and refined_node =
  { refined_obj : identifier * constr * types;
    refined_rettyp : types;
    refined_arg : int * int; (* Index counting lets or not *)
    refined_path : path;
    refined_term : EConstr.t;
    refined_filter : int list option;
    refined_args : constr list;
    refined_revctx : context_map;
    refined_newprob : context_map;
    refined_newprob_to_lhs : context_map;
    refined_newty : types }

and program =
  { program_info : program_info;
    program_prob : context_map;
    program_rec : rec_info option;
    program_splitting : splitting;
    program_term : constr }

and splitting_rhs = RProgram of constr | REmpty of int * splitting option array


val where_id : where_clause -> Id.t
val where_term : where_clause -> constr

val program_id : program -> Id.t
val program_type : program -> EConstr.t
val program_sign : program -> EConstr.rel_context
val program_arity : program -> EConstr.t
val program_impls : program -> Impargs.manual_implicits
val program_rec : program -> program_rec_info option

val pr_path : Evd.evar_map -> path -> Pp.t
val eq_path : path -> path -> bool

val pr_splitting_rhs : ?verbose:bool -> env -> env (* With wheres *) -> Evd.evar_map -> context_map -> splitting_rhs -> 
    EConstr.t -> Pp.t

val pr_splitting : env -> Evd.evar_map -> ?verbose:bool -> splitting -> Pp.t
val ppsplit : splitting -> unit

val where_context : where_clause list -> rel_context

val pr_program_info : env -> Evd.evar_map -> program_info -> Pp.t

val context_map_of_splitting : splitting -> context_map

val check_splitting : env -> Evd.evar_map -> splitting -> unit

(** Compilation to Coq terms *)
val term_of_tree :
  env ->
  Evd.evar_map ref -> Sorts.t ->
  splitting ->
  constr * constr

type program_shape =
  | Single of program_info * context_map * rec_info option * splitting * constr
  | Mutual of program_info * context_map * rec_info * splitting * rel_context * constr

val make_program :
  env ->
  Evd.evar_map ref ->
  program_info ->
  context_map ->
  splitting ->
  rec_info option ->
  program_shape

val make_programs :
  Environ.env ->
  Evd.evar_map ref ->
  flags ->
  ?define_constants:bool ->
  (Syntax.program_info * Context_map.context_map * splitting *
   rec_info option)
    list -> program list

val make_single_program :
  env ->
  Evd.evar_map ref ->
  flags ->
  program_info ->
  context_map ->
  splitting ->
  rec_info option ->
  program

val define_one_program_constants : flags ->
  env ->
  Evd.evar_map ref ->
  Entries.universes_entry ->
  bool ->
  program -> (Constant.t * (int * int)) list * program

val define_program_constants : flags ->
  env ->
  Evd.evar_map ref ->
  Entries.universes_entry ->
  ?unfold:bool ->
  program list ->
  (Constant.t * (int * int)) list * program list

(** Compilation from splitting tree to terms. *)

val is_comp_obl : Evd.evar_map -> Id.t with_loc option -> Evar_kinds.t -> bool

type term_info = {
  term_id : Names.GlobRef.t;
  term_ustate : UState.t;
  base_id : string;
  poly : bool;
  scope : Locality.definition_scope;
  decl_kind : Decls.definition_object_kind;
  helpers_info : (Constant.t * (int * int)) list;
  comp_obls : Constant.t list; (** The recursive call proof obligations *)
  user_obls : Id.Set.t; (** The user proof obligations *)
}

type compiled_program_info = {
    program_cst : Constant.t;
    program_split_info : term_info }

val is_polymorphic : term_info -> bool

val define_mutual_nested : Environ.env ->
  Evd.evar_map ref ->
  ('a -> EConstr.t) ->
  (program_info * 'a) list ->
  (program_info * 'a * EConstr.t) list *
  (program_info * 'a * EConstr.constr) list

val define_mutual_nested_csts :
           Equations_common.flags ->
           Environ.env ->
           Evd.evar_map ref ->
           (Evd.evar_map ref -> 'a -> EConstr.t) ->
           (Syntax.program_info * 'a) list ->
           (Syntax.program_info * 'a * EConstr.t) list *
           (Syntax.program_info * 'a * EConstr.t) list

val define_programs :
  pm:Declare.OblState.t ->
  Environ.env ->
  Evd.evar_map ref ->
  UState.universe_decl ->
  Syntax.rec_type ->
  EConstr.rel_context ->
  Equations_common.flags ->
  ?unfold:bool ->
  program list ->
  (pm:Declare.OblState.t -> int -> program -> term_info -> unit * Declare.OblState.t) ->
  Declare.OblState.t * Declare.Proof.t option

val define_program_immediate :
  pm:Declare.OblState.t ->
  Environ.env ->
  Evd.evar_map ref ->
  UState.universe_decl ->
  Syntax.rec_type ->
  EConstr.rel_context ->
  Equations_common.flags ->
  ?unfold:bool ->
  program ->
  (program * term_info) * Declare.OblState.t * Declare.Proof.t option

val mapping_rhs : Evd.evar_map -> context_map -> splitting_rhs -> splitting_rhs
val map_rhs :
  (constr -> constr) ->
  (int -> int) -> splitting_rhs -> splitting_rhs
val map_split : (constr -> constr) -> splitting -> splitting

val simplify_evars : Evd.evar_map -> EConstr.t -> EConstr.t
