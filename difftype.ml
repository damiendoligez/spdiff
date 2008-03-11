open Gtree

type 'a diff = 
    | ID of 'a 
    | ADD of 'a 
    | RM of 'a 
    | UP of 'a * 'a
    | SEQ of 'a diff * 'a diff

let rec csize bp = match bp with
| UP(t1,t2) -> gsize t1 + gsize t2
| SEQ(p1,p2) -> csize p1 + csize p2
