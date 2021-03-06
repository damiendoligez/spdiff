(*
* Copyright 2005-2009, Ecole des Mines de Nantes, University of Copenhagen
* Yoann Padioleau, Julia Lawall, Rene Rydhof Hansen, Henrik Stuart, Gilles Muller, Jesper Andersen
* This file is part of Coccinelle.
* 
* Coccinelle is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, according to version 2 of the License.
* 
* Coccinelle is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with Coccinelle.  If not, see <http://www.gnu.org/licenses/>.
* 
* The authors reserve the right to distribute this or future versions of
* Coccinelle under other licenses.
*)


(* A('t,'c) is an atom with content 'c and type 't while C('t,alist)
   is a node of type 't with arguments "alist"
*)

open Hashcons

type gtree = gtree_node hash_consed
and gtree_node =
    | A of string * string
    | C of string * gtree list

module Gtree_node = struct
  type t = gtree_node
  let equal t1 t2 = match t1, t2 with
  | A (t1,v1), A (t2,v2) -> t1 = t2 && v1 = v2
  | C (t1,ts1), C (t2,ts2) when 
      List.length ts1 = List.length ts2 -> t1 = t2 &&
      List.for_all2 (fun t t' -> t == t') ts1 ts2
  | _ -> false
  let hash = function
    | A (t, v) -> abs(19 * (Hashtbl.hash t + Hashtbl.hash v))
    | C (t,ts) -> abs(List.fold_left (fun acc_k t' -> 
        19 * (t'.hkey + acc_k)
        ) (Hashtbl.hash t) ts)
end

module HGtree = Make(Gtree_node)

let termht = HGtree.create 100313

let view t = t.node
let hcons t = HGtree.hashcons termht t

let mkA (a,b) = hcons (A(a,b))
let mkC (a,ts) = hcons (C(a,ts))

let rec occurs_loc small large =
  small == large ||
  (match view large with
    | C(ct, ts) -> List.exists (function t -> occurs_loc small t) ts
    | _ -> false
  )

let embedded a b =
  occurs_loc a b || occurs_loc b a

(* 
 * size of tree without metavariables and not 
 * counting typed expressions
 *)
let rec gsize t =
  match view t with
  | A ("meta", _) -> 0
  | A _ -> 1
  | C ("TYPEDEXP", _) -> 0
  | C(ct, ts) -> 1 + List.fold_left 
      (fun a b -> a + gsize b) 1 ts


(*
 * Returns a pair of ints where the first component 
 * is the concrete size of a tree (including embedded 
 * types) and the second component is the number of 
 * distinct metavariables
 *)
let pair_size t =
  let rec loop ((c,m),env) t = 
    match view t with
    | A ("meta", x) -> 	
        if List.mem x env
        then (c,m), env
        else (c,m+1), x :: env
    | A _ -> (c+1,m), env
    | C(_, ts) -> List.fold_left loop ((c+1,m), env) ts
  in
    fst (loop ((0,0),[]) t)

(* return true iff t1 is less than or eq to t2
 * should ONLY use this comparison for *equivalent*
 * patterns; it does not really make sense otherwise
*)
let leq_pair_size t1 t2 =
  let (c1,m1) = pair_size t1 in
  let (c2,m2) = pair_size t2 in
    if c1 <= c2
    then 
      if c1 = c2
      then m2 <= m1 
      else true (* t1 < t2 *)
    else false (* t2 < t1 *)

(*
 * size of tree without metavariables, but including 
 * embedded types
 *)
let rec zsize t =
  match view t with
  | A ("meta", _) -> 0
  | A (at, ac) -> 1 (* String.length ac *)
  | C ("TYPEDEXP", [ft;id]) -> zsize ft + zsize id
  | C(ct, ts) -> 1 + List.fold_left 
      (fun a b -> a + zsize b) 1 ts

let rec gdepth t =
  match view t with
  | A _ -> 0
  | C(ct, ts) -> List.fold_left
      (fun a b -> max a (gdepth b)) 1 ts


exception Found_leaf
(* returns true iff t does not contain any leaves *)
let no_leaves t = 
  let rec loop t = match view t with
    | A("meta",_) -> ()
    | A(_,_) -> raise Found_leaf
    | C(_,ts) -> List.iter loop ts;
  in
    try 
      begin 
	loop t;
	true
      end
    with Found_leaf -> false
