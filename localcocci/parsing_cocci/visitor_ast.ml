module Ast = Ast_cocci

(* --------------------------------------------------------------------- *)
(* Generic traversal: combiner *)
(* parameters:
   combining function
   treatment of: mcode, identifiers, expressions, fullTypes, types,
   declarations, statements, toplevels
   default value for options *)

type 'a combiner =
    {combiner_ident : Ast.ident -> 'a;
     combiner_expression : Ast.expression -> 'a;
     combiner_fullType : Ast.fullType -> 'a;
     combiner_typeC : Ast.typeC -> 'a;
     combiner_declaration : Ast.declaration -> 'a;
     combiner_initialiser : Ast.initialiser -> 'a;
     combiner_parameter : Ast.parameterTypeDef -> 'a;
     combiner_parameter_list : Ast.parameter_list -> 'a;
     combiner_rule_elem : Ast.rule_elem -> 'a;
     combiner_statement : Ast.statement -> 'a;
     combiner_case_line : Ast.case_line -> 'a;
     combiner_top_level : Ast.top_level -> 'a;
     combiner_anything : Ast.anything  -> 'a;
     combiner_expression_dots : Ast.expression Ast.dots -> 'a;
     combiner_statement_dots : Ast.statement Ast.dots -> 'a;
     combiner_declaration_dots : Ast.declaration Ast.dots -> 'a}

type ('mc,'a) cmcode = 'a combiner -> 'mc Ast_cocci.mcode -> 'a
type ('cd,'a) ccode = 'a combiner -> ('cd -> 'a) -> 'cd -> 'a


let combiner bind option_default
    meta_mcodefn string_mcodefn const_mcodefn assign_mcodefn fix_mcodefn
    unary_mcodefn binary_mcodefn
    cv_mcodefn sign_mcodefn struct_mcodefn storage_mcodefn
    inc_file_mcodefn
    expdotsfn paramdotsfn stmtdotsfn decldotsfn
    identfn exprfn ftfn tyfn initfn paramfn declfn rulefn stmtfn casefn
    topfn anyfn =
  let multibind l =
    let rec loop = function
	[] -> option_default
      |	[x] -> x
      |	x::xs -> bind x (loop xs) in
    loop l in
  let get_option f = function
      Some x -> f x
    | None -> option_default in

  let rec meta_mcode x = meta_mcodefn all_functions x
  and string_mcode x = string_mcodefn all_functions x
  and const_mcode x = const_mcodefn all_functions x
  and assign_mcode x = assign_mcodefn all_functions x
  and fix_mcode x = fix_mcodefn all_functions x
  and unary_mcode x = unary_mcodefn all_functions x
  and binary_mcode x = binary_mcodefn all_functions x
  and cv_mcode x = cv_mcodefn all_functions x
  and sign_mcode x = sign_mcodefn all_functions x
  and struct_mcode x = struct_mcodefn all_functions x
  and storage_mcode x = storage_mcodefn all_functions x
  and inc_file_mcode x = inc_file_mcodefn all_functions x

  and expression_dots d =
    let k d =
      match Ast.unwrap d with
	Ast.DOTS(l) | Ast.CIRCLES(l) | Ast.STARS(l) ->
	  multibind (List.map expression l) in
    expdotsfn all_functions k d

  and parameter_dots d =
    let k d =
      match Ast.unwrap d with
	Ast.DOTS(l) | Ast.CIRCLES(l) | Ast.STARS(l) ->
	  multibind (List.map parameterTypeDef l) in
    paramdotsfn all_functions k d

  and statement_dots d =
    let k d =
      match Ast.unwrap d with
	Ast.DOTS(l) | Ast.CIRCLES(l) | Ast.STARS(l) ->
	  multibind (List.map statement l) in
    stmtdotsfn all_functions k d

  and declaration_dots d =
    let k d =
      match Ast.unwrap d with
	Ast.DOTS(l) | Ast.CIRCLES(l) | Ast.STARS(l) ->
	  multibind (List.map declaration l) in
    decldotsfn all_functions k d

  and ident i =
    let k i =
      match Ast.unwrap i with
	Ast.Id(name) -> string_mcode name
      | Ast.MetaId(name,_,_,_) -> meta_mcode name
      | Ast.MetaFunc(name,_,_,_) -> meta_mcode name
      | Ast.MetaLocalFunc(name,_,_,_) -> meta_mcode name
      | Ast.OptIdent(id) -> ident id
      | Ast.UniqueIdent(id) -> ident id in
    identfn all_functions k i

  and expression e =
    let k e =
      match Ast.unwrap e with
	Ast.Ident(id) -> ident id
      | Ast.Constant(const) -> const_mcode const
      | Ast.FunCall(fn,lp,args,rp) ->
	  multibind [expression fn; string_mcode lp; expression_dots args;
		      string_mcode rp]
      | Ast.Assignment(left,op,right,simple) ->
	  multibind [expression left; assign_mcode op; expression right]
      | Ast.CondExpr(exp1,why,exp2,colon,exp3) ->
	  multibind [expression exp1; string_mcode why;
		      get_option expression exp2; string_mcode colon;
		      expression exp3]
      | Ast.Postfix(exp,op) -> bind (expression exp) (fix_mcode op)
      | Ast.Infix(exp,op) -> bind (fix_mcode op) (expression exp)
      | Ast.Unary(exp,op) -> bind (unary_mcode op) (expression exp)
      | Ast.Binary(left,op,right) ->
	  multibind [expression left; binary_mcode op; expression right]
      | Ast.Nested(left,op,right) ->
	  multibind [expression left; binary_mcode op; expression right]
      | Ast.Paren(lp,exp,rp) ->
	  multibind [string_mcode lp; expression exp; string_mcode rp]
      | Ast.ArrayAccess(exp1,lb,exp2,rb) ->
	  multibind
	    [expression exp1; string_mcode lb; expression exp2;
	      string_mcode rb]
      | Ast.RecordAccess(exp,pt,field) ->
	  multibind [expression exp; string_mcode pt; ident field]
      | Ast.RecordPtAccess(exp,ar,field) ->
	  multibind [expression exp; string_mcode ar; ident field]
      | Ast.Cast(lp,ty,rp,exp) ->
	  multibind
	    [string_mcode lp; fullType ty; string_mcode rp; expression exp]
      | Ast.SizeOfExpr(szf,exp) ->
	  multibind [string_mcode szf; expression exp]
      | Ast.SizeOfType(szf,lp,ty,rp) ->
	  multibind
	    [string_mcode szf; string_mcode lp; fullType ty; string_mcode rp]
      | Ast.TypeExp(ty) -> fullType ty
      | Ast.MetaErr(name,_,_,_)
      | Ast.MetaExpr(name,_,_,_,_,_)
      | Ast.MetaExprList(name,_,_,_) -> meta_mcode name
      | Ast.EComma(cm) -> string_mcode cm
      | Ast.DisjExpr(exp_list) -> multibind (List.map expression exp_list)
      | Ast.NestExpr(expr_dots,whencode,multi) ->
	  bind (expression_dots expr_dots) (get_option expression whencode)
      | Ast.Edots(dots,whencode) | Ast.Ecircles(dots,whencode)
      | Ast.Estars(dots,whencode) ->
	  bind (string_mcode dots) (get_option expression whencode)
      | Ast.OptExp(exp) | Ast.UniqueExp(exp) ->
	  expression exp in
    exprfn all_functions k e

  and fullType ft =
    let k ft =
      match Ast.unwrap ft with
	Ast.Type(cv,ty) -> bind (get_option cv_mcode cv) (typeC ty)
      | Ast.DisjType(types) -> multibind (List.map fullType types)
      | Ast.OptType(ty) -> fullType ty
      | Ast.UniqueType(ty) -> fullType ty in
    ftfn all_functions k ft

  and function_pointer (ty,lp1,star,rp1,lp2,params,rp2) extra =
    (* have to put the treatment of the identifier into the right position *)
    multibind
      ([fullType ty; string_mcode lp1; string_mcode star] @ extra @
       [string_mcode rp1;
	 string_mcode lp2; parameter_dots params; string_mcode rp2])

  and function_type (ty,lp1,params,rp1) extra =
    (* have to put the treatment of the identifier into the right position *)
    multibind
      ([get_option fullType ty] @ extra @
       [string_mcode lp1; parameter_dots params; string_mcode rp1])

  and array_type (ty,lb,size,rb) extra =
    multibind
      ([fullType ty] @ extra @
       [string_mcode lb; get_option expression size; string_mcode rb])

  and typeC ty =
    let k ty =
      match Ast.unwrap ty with
	Ast.BaseType(ty,strings) -> multibind (List.map string_mcode strings)
      | Ast.SignedT(sgn,ty) -> bind (sign_mcode sgn) (get_option typeC ty)
      | Ast.Pointer(ty,star) ->
	  bind (fullType ty) (string_mcode star)
      | Ast.FunctionPointer(ty,lp1,star,rp1,lp2,params,rp2) ->
	  function_pointer (ty,lp1,star,rp1,lp2,params,rp2) []
      |	Ast.FunctionType (_,ty,lp1,params,rp1) ->
	  function_type (ty,lp1,params,rp1) []
      | Ast.Array(ty,lb,size,rb) -> array_type (ty,lb,size,rb) []
      | Ast.EnumName(kind,name) -> bind (string_mcode kind) (ident name)
      | Ast.StructUnionName(kind,name) ->
	  bind (struct_mcode kind) (get_option ident name)
      | Ast.StructUnionDef(ty,lb,decls,rb) ->
	  multibind
	    [fullType ty; string_mcode lb; declaration_dots decls;
	      string_mcode rb]
      | Ast.TypeName(name) -> string_mcode name
      | Ast.MetaType(name,_,_) -> meta_mcode name in
    tyfn all_functions k ty

  and named_type ty id =
    match Ast.unwrap ty with
      Ast.Type(None,ty1) ->
	(match Ast.unwrap ty1 with
	  Ast.FunctionPointer(ty,lp1,star,rp1,lp2,params,rp2) ->
	    function_pointer (ty,lp1,star,rp1,lp2,params,rp2) [ident id]
	| Ast.FunctionType(_,ty,lp1,params,rp1) ->
	    function_type (ty,lp1,params,rp1) [ident id]
	| Ast.Array(ty,lb,size,rb) -> array_type (ty,lb,size,rb) [ident id]
	| _ -> bind (fullType ty) (ident id))
    | _ -> bind (fullType ty) (ident id)

  and declaration d =
    let k d =
      match Ast.unwrap d with
	Ast.Init(stg,ty,id,eq,ini,sem) ->
	  bind (get_option storage_mcode stg)
	    (bind (named_type ty id)
	       (multibind
		  [string_mcode eq; initialiser ini; string_mcode sem]))
      | Ast.UnInit(stg,ty,id,sem) ->
	  bind (get_option storage_mcode stg)
	    (bind (named_type ty id) (string_mcode sem))
      | Ast.MacroDecl(name,lp,args,rp,sem) ->
	  multibind
	    [ident name; string_mcode lp; expression_dots args;
	      string_mcode rp; string_mcode sem]
      | Ast.TyDecl(ty,sem) -> bind (fullType ty) (string_mcode sem)
      | Ast.Typedef(stg,ty,id,sem) ->
	  bind (string_mcode stg)
	    (bind (fullType ty) (bind (typeC id) (string_mcode sem)))
      | Ast.DisjDecl(decls) -> multibind (List.map declaration decls)
      |	Ast.Ddots(dots,whencode) ->
	  bind (string_mcode dots) (get_option declaration whencode)
      | Ast.MetaDecl(name,_,_) -> meta_mcode name
      | Ast.OptDecl(decl) -> declaration decl
      | Ast.UniqueDecl(decl) -> declaration decl in
    declfn all_functions k d

  and initialiser i =
    let k i =
      match Ast.unwrap i with
	Ast.MetaInit(name,_,_) -> meta_mcode name
      |	Ast.InitExpr(exp) -> expression exp
      | Ast.InitList(lb,initlist,rb,whencode) ->
	  multibind
	    [string_mcode lb;
	      multibind (List.map initialiser initlist);
	      string_mcode rb;
	      multibind (List.map initialiser whencode)]
      | Ast.InitGccName(name,eq,ini) ->
	  multibind [ident name; string_mcode eq; initialiser ini]
      | Ast.InitGccExt(designators,eq,ini) ->
	  multibind
	    ((List.map designator designators) @
	     [string_mcode eq; initialiser ini])
      | Ast.IComma(cm) -> string_mcode cm
      | Ast.OptIni(i) -> initialiser i
      | Ast.UniqueIni(i) -> initialiser i in
    initfn all_functions k i

  and designator = function
      Ast.DesignatorField(dot,id) -> bind (string_mcode dot) (ident id)
    | Ast.DesignatorIndex(lb,exp,rb) ->
	bind (string_mcode lb) (bind (expression exp) (string_mcode rb))
    | Ast.DesignatorRange(lb,min,dots,max,rb) ->
	multibind
	  [string_mcode lb; expression min; string_mcode dots;
	    expression max; string_mcode rb]

  and parameterTypeDef p =
    let k p =
      match Ast.unwrap p with
	Ast.VoidParam(ty) -> fullType ty
      | Ast.Param(ty,Some id) -> named_type ty id
      | Ast.Param(ty,None) -> fullType ty
      | Ast.MetaParam(name,_,_) -> meta_mcode name
      | Ast.MetaParamList(name,_,_,_) -> meta_mcode name
      | Ast.PComma(cm) -> string_mcode cm
      | Ast.Pdots(dots) -> string_mcode dots
      | Ast.Pcircles(dots) -> string_mcode dots
      | Ast.OptParam(param) -> parameterTypeDef param
      | Ast.UniqueParam(param) -> parameterTypeDef param in
    paramfn all_functions k p

  and rule_elem re =
    let k re =
      match Ast.unwrap re with
	Ast.FunHeader(_,_,fi,name,lp,params,rp) ->
	  multibind
	    ((List.map fninfo fi) @
	     [ident name;string_mcode lp;parameter_dots params;
	       string_mcode rp])
      | Ast.Decl(_,_,decl) -> declaration decl
      | Ast.SeqStart(brace) -> string_mcode brace
      | Ast.SeqEnd(brace) -> string_mcode brace
      | Ast.ExprStatement(exp,sem) ->
	  bind (expression exp) (string_mcode sem)
      | Ast.IfHeader(iff,lp,exp,rp) ->
	  multibind [string_mcode iff; string_mcode lp; expression exp;
		      string_mcode rp]
      | Ast.Else(els) -> string_mcode els
      | Ast.WhileHeader(whl,lp,exp,rp) ->
	  multibind [string_mcode whl; string_mcode lp; expression exp;
		      string_mcode rp]
      | Ast.DoHeader(d) -> string_mcode d
      | Ast.WhileTail(whl,lp,exp,rp,sem) ->
	  multibind [string_mcode whl; string_mcode lp; expression exp;
		      string_mcode rp; string_mcode sem]
      | Ast.ForHeader(fr,lp,e1,sem1,e2,sem2,e3,rp) ->
	  multibind [string_mcode fr; string_mcode lp;
		      get_option expression e1; string_mcode sem1;
		      get_option expression e2; string_mcode sem2;
		      get_option expression e3; string_mcode rp]
      | Ast.IteratorHeader(nm,lp,args,rp) ->
	  multibind [ident nm; string_mcode lp;
		      expression_dots args; string_mcode rp]
      | Ast.SwitchHeader(switch,lp,exp,rp) ->
	  multibind [string_mcode switch; string_mcode lp; expression exp;
		      string_mcode rp]
      | Ast.Break(br,sem) -> bind (string_mcode br) (string_mcode sem)
      | Ast.Continue(cont,sem) -> bind (string_mcode cont) (string_mcode sem)
      |	Ast.Label(l,dd) -> bind (ident l) (string_mcode dd)
      |	Ast.Goto(goto,l,sem) ->
	  bind (string_mcode goto) (bind (ident l) (string_mcode sem))
      | Ast.Return(ret,sem) -> bind (string_mcode ret) (string_mcode sem)
      | Ast.ReturnExpr(ret,exp,sem) ->
	  multibind [string_mcode ret; expression exp; string_mcode sem]
      | Ast.MetaStmt(name,_,_,_) -> meta_mcode name
      | Ast.MetaStmtList(name,_,_) -> meta_mcode name
      | Ast.MetaRuleElem(name,_,_) -> meta_mcode name
      | Ast.Exp(exp) -> expression exp
      | Ast.TopExp(exp) -> expression exp
      | Ast.Ty(ty) -> fullType ty
      | Ast.TopInit(init) -> initialiser init
      |	Ast.Include(inc,name) -> bind (string_mcode inc) (inc_file_mcode name)
      |	Ast.DefineHeader(def,id,params) ->
	  multibind [string_mcode def; ident id; define_parameters params]
      |	Ast.Default(def,colon) -> bind (string_mcode def) (string_mcode colon)
      |	Ast.Case(case,exp,colon) ->
	  multibind [string_mcode case; expression exp; string_mcode colon]
      |	Ast.DisjRuleElem(res) -> multibind (List.map rule_elem res) in
    rulefn all_functions k re

  (* not parameterizable for now... *)
  and define_parameters p =
    let k p =
      match Ast.unwrap p with
	Ast.NoParams -> option_default
      | Ast.DParams(lp,params,rp) ->
	  multibind
	    [string_mcode lp; define_param_dots params; string_mcode rp] in
    k p

  and define_param_dots d =
    let k d =
      match Ast.unwrap d with
	Ast.DOTS(l) | Ast.CIRCLES(l) | Ast.STARS(l) ->
	  multibind (List.map define_param l) in
    k d

  and define_param p =
    let k p =
      match Ast.unwrap p with
	Ast.DParam(id) -> ident id
      | Ast.DPComma(comma) -> string_mcode comma
      | Ast.DPdots(d) -> string_mcode d
      | Ast.DPcircles(c) -> string_mcode c
      | Ast.OptDParam(dp) -> define_param dp
      | Ast.UniqueDParam(dp) -> define_param dp in
    k p

  (* discard the result, because the statement is assumed to be already
     represented elsewhere in the code *)
  and process_bef_aft s =
    match Ast.get_dots_bef_aft s with
      Ast.NoDots -> ()
    | Ast.DroppingBetweenDots(stm,ind) -> let _ = statement stm in ()
    | Ast.AddingBetweenDots(stm,ind) -> let _ = statement stm in ()

  and statement s =
    process_bef_aft s;
    let k s =
      match Ast.unwrap s with
	Ast.Seq(lbrace,decls,body,rbrace) ->
	  multibind [rule_elem lbrace; statement_dots decls;
		      statement_dots body; rule_elem rbrace]
      | Ast.IfThen(header,branch,_) ->
	  multibind [rule_elem header; statement branch]
      | Ast.IfThenElse(header,branch1,els,branch2,_) ->
	  multibind [rule_elem header; statement branch1; rule_elem els;
		      statement branch2]
      | Ast.While(header,body,_) ->
	  multibind [rule_elem header; statement body]
      | Ast.Do(header,body,tail) ->
	  multibind [rule_elem header; statement body; rule_elem tail]
      | Ast.For(header,body,_) -> multibind [rule_elem header; statement body]
      | Ast.Iterator(header,body,_) ->
	  multibind [rule_elem header; statement body]
      |	Ast.Switch(header,lb,cases,rb) ->
	  multibind [rule_elem header;rule_elem lb;
		      multibind (List.map case_line cases);
		      rule_elem rb]
      | Ast.Atomic(re) -> rule_elem re
      | Ast.Disj(stmt_dots_list) ->
	  multibind (List.map statement_dots stmt_dots_list)
      | Ast.Nest(stmt_dots,whn,_,_,_) ->
	  bind (statement_dots stmt_dots)
	    (multibind (List.map (whencode statement_dots statement) whn))
      | Ast.FunDecl(header,lbrace,decls,body,rbrace) ->
	  multibind [rule_elem header; rule_elem lbrace;
		      statement_dots decls; statement_dots body;
		      rule_elem rbrace]
      | Ast.Define(header,body) ->
	  bind (rule_elem header) (statement_dots body)
      | Ast.Dots(d,whn,_,_) | Ast.Circles(d,whn,_,_) | Ast.Stars(d,whn,_,_) ->
	  bind (string_mcode d)
	    (multibind (List.map (whencode statement_dots statement) whn))
      | Ast.OptStm(stmt) | Ast.UniqueStm(stmt) ->
	  statement stmt in
    stmtfn all_functions k s

  and fninfo = function
      Ast.FStorage(stg) -> storage_mcode stg
    | Ast.FType(ty) -> fullType ty
    | Ast.FInline(inline) -> string_mcode inline
    | Ast.FAttr(attr) -> string_mcode attr

  and whencode notfn alwaysfn = function
      Ast.WhenNot a -> notfn a
    | Ast.WhenAlways a -> alwaysfn a
    | Ast.WhenModifier(_) -> option_default
    | Ast.WhenNotTrue(e) -> rule_elem e
    | Ast.WhenNotFalse(e) -> rule_elem e

  and case_line c =
    let k c =
      match Ast.unwrap c with
	Ast.CaseLine(header,code) ->
	  bind (rule_elem header) (statement_dots code)
      |	Ast.OptCase(case) -> case_line case in
    casefn all_functions k c

  and top_level t =
    let k t =
      match Ast.unwrap t with
	Ast.FILEINFO(old_file,new_file) ->
	  bind (string_mcode old_file) (string_mcode new_file)
      | Ast.DECL(stmt) -> statement stmt
      | Ast.CODE(stmt_dots) -> statement_dots stmt_dots
      | Ast.ERRORWORDS(exps) -> multibind (List.map expression exps) in
    topfn all_functions k t

  and anything a =
    let k = function
	(*in many cases below, the thing is not even mcode, so we do nothing*)
	Ast.FullTypeTag(ft) -> fullType ft
      | Ast.BaseTypeTag(bt) -> option_default
      | Ast.StructUnionTag(su) -> option_default
      | Ast.SignTag(sgn) -> option_default
      | Ast.IdentTag(id) -> ident id
      | Ast.ExpressionTag(exp) -> expression exp
      | Ast.ConstantTag(cst) -> option_default
      | Ast.UnaryOpTag(unop) -> option_default
      | Ast.AssignOpTag(asgnop) -> option_default
      | Ast.FixOpTag(fixop) -> option_default
      | Ast.BinaryOpTag(binop) -> option_default
      | Ast.ArithOpTag(arithop) -> option_default
      | Ast.LogicalOpTag(logop) -> option_default
      | Ast.DeclarationTag(decl) -> declaration decl
      | Ast.InitTag(ini) -> initialiser ini
      | Ast.StorageTag(stg) -> option_default
      | Ast.IncFileTag(stg) -> option_default
      | Ast.Rule_elemTag(rule) -> rule_elem rule
      | Ast.StatementTag(rule) -> statement rule
      | Ast.CaseLineTag(case) -> case_line case
      | Ast.ConstVolTag(cv) -> option_default
      | Ast.Token(tok,info) -> option_default
      | Ast.Pragma(str) -> option_default
      | Ast.Code(cd) -> top_level cd
      | Ast.ExprDotsTag(ed) -> expression_dots ed
      | Ast.ParamDotsTag(pd) -> parameter_dots pd
      | Ast.StmtDotsTag(sd) -> statement_dots sd
      | Ast.DeclDotsTag(sd) -> declaration_dots sd
      | Ast.TypeCTag(ty) -> typeC ty
      | Ast.ParamTag(param) -> parameterTypeDef param
      | Ast.SgrepStartTag(tok) -> option_default
      | Ast.SgrepEndTag(tok) -> option_default in
    anyfn all_functions k a

  and all_functions =
    {combiner_ident = ident;
      combiner_expression = expression;
      combiner_fullType = fullType;
      combiner_typeC = typeC;
      combiner_declaration = declaration;
      combiner_initialiser = initialiser;
      combiner_parameter = parameterTypeDef;
      combiner_parameter_list = parameter_dots;
      combiner_rule_elem = rule_elem;
      combiner_statement = statement;
      combiner_case_line = case_line;
      combiner_top_level = top_level;
      combiner_anything = anything;
      combiner_expression_dots = expression_dots;
      combiner_statement_dots = statement_dots;
      combiner_declaration_dots = declaration_dots} in
  all_functions

(* ---------------------------------------------------------------------- *)

type 'a inout = 'a -> 'a (* for specifying the type of rebuilder *)

type rebuilder =
    {rebuilder_ident : Ast.ident inout;
      rebuilder_expression : Ast.expression inout;
      rebuilder_fullType : Ast.fullType inout;
      rebuilder_typeC : Ast.typeC inout;
      rebuilder_declaration : Ast.declaration inout;
      rebuilder_initialiser : Ast.initialiser inout;
      rebuilder_parameter : Ast.parameterTypeDef inout;
      rebuilder_parameter_list : Ast.parameter_list inout;
      rebuilder_statement : Ast.statement inout;
      rebuilder_case_line : Ast.case_line inout;
      rebuilder_rule_elem : Ast.rule_elem inout;
      rebuilder_top_level : Ast.top_level inout;
      rebuilder_expression_dots : Ast.expression Ast.dots inout;
      rebuilder_statement_dots : Ast.statement Ast.dots inout;
      rebuilder_declaration_dots : Ast.declaration Ast.dots inout;
      rebuilder_define_param_dots : Ast.define_param Ast.dots inout;
      rebuilder_define_param : Ast.define_param inout;
      rebuilder_define_parameters : Ast.define_parameters inout;
      rebuilder_anything : Ast.anything inout}

type 'mc rmcode = 'mc Ast.mcode inout
type 'cd rcode = rebuilder -> ('cd inout) -> 'cd inout


let rebuilder
    meta_mcode string_mcode const_mcode assign_mcode fix_mcode unary_mcode
    binary_mcode cv_mcode sign_mcode struct_mcode storage_mcode
    inc_file_mcode
    expdotsfn paramdotsfn stmtdotsfn decldotsfn
    identfn exprfn ftfn tyfn initfn paramfn declfn rulefn stmtfn casefn
    topfn anyfn =
  let get_option f = function
      Some x -> Some (f x)
    | None -> None in
  let rec expression_dots d =
    let k d =
      Ast.rewrap d
	(match Ast.unwrap d with
	  Ast.DOTS(l) -> Ast.DOTS(List.map expression l)
	| Ast.CIRCLES(l) -> Ast.CIRCLES(List.map expression l)
	| Ast.STARS(l) -> Ast.STARS(List.map expression l)) in
    expdotsfn all_functions k d

  and parameter_dots d =
    let k d =
      Ast.rewrap d
	(match Ast.unwrap d with
	  Ast.DOTS(l) -> Ast.DOTS(List.map parameterTypeDef l)
	| Ast.CIRCLES(l) -> Ast.CIRCLES(List.map parameterTypeDef l)
	| Ast.STARS(l) -> Ast.STARS(List.map parameterTypeDef l)) in
    paramdotsfn all_functions k d

  and statement_dots d =
    let k d =
      Ast.rewrap d
	(match Ast.unwrap d with
	  Ast.DOTS(l) -> Ast.DOTS(List.map statement l)
	| Ast.CIRCLES(l) -> Ast.CIRCLES(List.map statement l)
	| Ast.STARS(l) -> Ast.STARS(List.map statement l)) in
    stmtdotsfn all_functions k d

  and declaration_dots d =
    let k d =
      Ast.rewrap d
	(match Ast.unwrap d with
	  Ast.DOTS(l) -> Ast.DOTS(List.map declaration l)
	| Ast.CIRCLES(l) -> Ast.CIRCLES(List.map declaration l)
	| Ast.STARS(l) -> Ast.STARS(List.map declaration l)) in
    decldotsfn all_functions k d

  and ident i =
    let k i =
      Ast.rewrap i
	(match Ast.unwrap i with
	  Ast.Id(name) -> Ast.Id(string_mcode name)
	| Ast.MetaId(name,constraints,keep,inherited) ->
	    Ast.MetaId(meta_mcode name,constraints,keep,inherited)
	| Ast.MetaFunc(name,constraints,keep,inherited) ->
	    Ast.MetaFunc(meta_mcode name,constraints,keep,inherited)
	| Ast.MetaLocalFunc(name,constraints,keep,inherited) ->
	    Ast.MetaLocalFunc(meta_mcode name,constraints,keep,inherited)
	| Ast.OptIdent(id) -> Ast.OptIdent(ident id)
	| Ast.UniqueIdent(id) -> Ast.UniqueIdent(ident id)) in
    identfn all_functions k i

  and expression e =
    let k e =
      Ast.rewrap e
	(match Ast.unwrap e with
	  Ast.Ident(id) -> Ast.Ident(ident id)
	| Ast.Constant(const) -> Ast.Constant(const_mcode const)
	| Ast.FunCall(fn,lp,args,rp) ->
	    Ast.FunCall(expression fn, string_mcode lp, expression_dots args,
			string_mcode rp)
	| Ast.Assignment(left,op,right,simple) ->
	    Ast.Assignment(expression left, assign_mcode op, expression right,
			   simple)
	| Ast.CondExpr(exp1,why,exp2,colon,exp3) ->
	    Ast.CondExpr(expression exp1, string_mcode why,
			 get_option expression exp2, string_mcode colon,
			 expression exp3)
	| Ast.Postfix(exp,op) -> Ast.Postfix(expression exp,fix_mcode op)
	| Ast.Infix(exp,op) -> Ast.Infix(expression exp,fix_mcode op)
	| Ast.Unary(exp,op) -> Ast.Unary(expression exp,unary_mcode op)
	| Ast.Binary(left,op,right) ->
	    Ast.Binary(expression left, binary_mcode op, expression right)
	| Ast.Nested(left,op,right) ->
	    Ast.Nested(expression left, binary_mcode op, expression right)
	| Ast.Paren(lp,exp,rp) ->
	    Ast.Paren(string_mcode lp, expression exp, string_mcode rp)
	| Ast.ArrayAccess(exp1,lb,exp2,rb) ->
	    Ast.ArrayAccess(expression exp1, string_mcode lb, expression exp2,
			    string_mcode rb)
	| Ast.RecordAccess(exp,pt,field) ->
	    Ast.RecordAccess(expression exp, string_mcode pt, ident field)
	| Ast.RecordPtAccess(exp,ar,field) ->
	    Ast.RecordPtAccess(expression exp, string_mcode ar, ident field)
	| Ast.Cast(lp,ty,rp,exp) ->
	    Ast.Cast(string_mcode lp, fullType ty, string_mcode rp,
		     expression exp)
	| Ast.SizeOfExpr(szf,exp) ->
	    Ast.SizeOfExpr(string_mcode szf, expression exp)
	| Ast.SizeOfType(szf,lp,ty,rp) ->
	    Ast.SizeOfType(string_mcode szf,string_mcode lp, fullType ty,
                           string_mcode rp)
	| Ast.TypeExp(ty) -> Ast.TypeExp(fullType ty)
	| Ast.MetaErr(name,constraints,keep,inherited) ->
	    Ast.MetaErr(meta_mcode name,constraints,keep,inherited)
	| Ast.MetaExpr(name,constraints,keep,ty,form,inherited) ->
	    Ast.MetaExpr(meta_mcode name,constraints,keep,ty,form,inherited)
	| Ast.MetaExprList(name,lenname_inh,keep,inherited) ->
	    Ast.MetaExprList(meta_mcode name,lenname_inh,keep,inherited)
	| Ast.EComma(cm) -> Ast.EComma(string_mcode cm)
	| Ast.DisjExpr(exp_list) -> Ast.DisjExpr(List.map expression exp_list)
	| Ast.NestExpr(expr_dots,whencode,multi) ->
	    Ast.NestExpr(expression_dots expr_dots,
			 get_option expression whencode,multi)
	| Ast.Edots(dots,whencode) ->
	    Ast.Edots(string_mcode dots,get_option expression whencode)
	| Ast.Ecircles(dots,whencode) ->
	    Ast.Ecircles(string_mcode dots,get_option expression whencode)
	| Ast.Estars(dots,whencode) ->
	    Ast.Estars(string_mcode dots,get_option expression whencode)
	| Ast.OptExp(exp) -> Ast.OptExp(expression exp)
	| Ast.UniqueExp(exp) -> Ast.UniqueExp(expression exp)) in
    exprfn all_functions k e

  and fullType ft =
    let k ft =
      Ast.rewrap ft
	(match Ast.unwrap ft with
	  Ast.Type(cv,ty) -> Ast.Type (get_option cv_mcode cv, typeC ty)
	| Ast.DisjType(types) -> Ast.DisjType(List.map fullType types)
	| Ast.OptType(ty) -> Ast.OptType(fullType ty)
	| Ast.UniqueType(ty) -> Ast.UniqueType(fullType ty)) in
    ftfn all_functions k ft

  and typeC ty =
    let k ty =
      Ast.rewrap ty
	(match Ast.unwrap ty with
	  Ast.BaseType(ty,strings) ->
	    Ast.BaseType (ty, List.map string_mcode strings)
	| Ast.SignedT(sgn,ty) ->
	    Ast.SignedT(sign_mcode sgn,get_option typeC ty)
	| Ast.Pointer(ty,star) ->
	    Ast.Pointer (fullType ty, string_mcode star)
	| Ast.FunctionPointer(ty,lp1,star,rp1,lp2,params,rp2) ->
	    Ast.FunctionPointer(fullType ty,string_mcode lp1,string_mcode star,
				string_mcode rp1,string_mcode lp2,
				parameter_dots params,
				string_mcode rp2)
	| Ast.FunctionType(allminus,ty,lp,params,rp) ->
	    Ast.FunctionType(allminus,get_option fullType ty,string_mcode lp,
			     parameter_dots params,string_mcode rp)
	| Ast.Array(ty,lb,size,rb) ->
	    Ast.Array(fullType ty, string_mcode lb,
		      get_option expression size, string_mcode rb)
	| Ast.EnumName(kind,name) ->
	    Ast.EnumName(string_mcode kind, ident name)
	| Ast.StructUnionName(kind,name) ->
	    Ast.StructUnionName (struct_mcode kind, get_option ident name)
	| Ast.StructUnionDef(ty,lb,decls,rb) ->
	    Ast.StructUnionDef (fullType ty,
				string_mcode lb, declaration_dots decls,
				string_mcode rb)
	| Ast.TypeName(name) -> Ast.TypeName(string_mcode name)
	| Ast.MetaType(name,keep,inherited) ->
	    Ast.MetaType(meta_mcode name,keep,inherited)) in
    tyfn all_functions k ty

  and declaration d =
    let k d =
      Ast.rewrap d
	(match Ast.unwrap d with
	  Ast.Init(stg,ty,id,eq,ini,sem) ->
	    Ast.Init(get_option storage_mcode stg, fullType ty, ident id,
		     string_mcode eq, initialiser ini, string_mcode sem)
	| Ast.UnInit(stg,ty,id,sem) ->
	    Ast.UnInit(get_option storage_mcode stg, fullType ty, ident id,
		       string_mcode sem)
	| Ast.MacroDecl(name,lp,args,rp,sem) ->
	    Ast.MacroDecl(ident name, string_mcode lp, expression_dots args,
			  string_mcode rp,string_mcode sem)
	| Ast.TyDecl(ty,sem) -> Ast.TyDecl(fullType ty, string_mcode sem)
	| Ast.Typedef(stg,ty,id,sem) ->
	    Ast.Typedef(string_mcode stg, fullType ty, typeC id,
			string_mcode sem)
	| Ast.DisjDecl(decls) -> Ast.DisjDecl(List.map declaration decls)
	| Ast.Ddots(dots,whencode) ->
	    Ast.Ddots(string_mcode dots, get_option declaration whencode)
	| Ast.MetaDecl(name,keep,inherited) ->
	    Ast.MetaDecl(meta_mcode name,keep,inherited)
	| Ast.OptDecl(decl) -> Ast.OptDecl(declaration decl)
	| Ast.UniqueDecl(decl) -> Ast.UniqueDecl(declaration decl)) in
    declfn all_functions k d

  and initialiser i =
    let k i =
      Ast.rewrap i
	(match Ast.unwrap i with
	  Ast.MetaInit(name,keep,inherited) ->
	    Ast.MetaInit(meta_mcode name,keep,inherited)
	| Ast.InitExpr(exp) -> Ast.InitExpr(expression exp)
	| Ast.InitList(lb,initlist,rb,whencode) ->
	    Ast.InitList(string_mcode lb, List.map initialiser initlist,
			 string_mcode rb, List.map initialiser whencode)
	| Ast.InitGccName(name,eq,ini) ->
	    Ast.InitGccName(ident name, string_mcode eq, initialiser ini)
	| Ast.InitGccExt(designators,eq,ini) ->
	    Ast.InitGccExt
	      (List.map designator designators, string_mcode eq,
	       initialiser ini)
	| Ast.IComma(cm) -> Ast.IComma(string_mcode cm)
	| Ast.OptIni(i) -> Ast.OptIni(initialiser i)
	| Ast.UniqueIni(i) -> Ast.UniqueIni(initialiser i)) in
    initfn all_functions k i

  and designator = function
      Ast.DesignatorField(dot,id) ->
	Ast.DesignatorField(string_mcode dot,ident id)
    | Ast.DesignatorIndex(lb,exp,rb) ->
	Ast.DesignatorIndex(string_mcode lb,expression exp,string_mcode rb)
    | Ast.DesignatorRange(lb,min,dots,max,rb) ->
	Ast.DesignatorRange(string_mcode lb,expression min,string_mcode dots,
			     expression max,string_mcode rb)

  and parameterTypeDef p =
    let k p =
      Ast.rewrap p
	(match Ast.unwrap p with
	  Ast.VoidParam(ty) -> Ast.VoidParam(fullType ty)
	| Ast.Param(ty,id) -> Ast.Param(fullType ty, get_option ident id)
	| Ast.MetaParam(name,keep,inherited) ->
	    Ast.MetaParam(meta_mcode name,keep,inherited)
	| Ast.MetaParamList(name,lenname_inh,keep,inherited) ->
	    Ast.MetaParamList(meta_mcode name,lenname_inh,keep,inherited)
	| Ast.PComma(cm) -> Ast.PComma(string_mcode cm)
	| Ast.Pdots(dots) -> Ast.Pdots(string_mcode dots)
	| Ast.Pcircles(dots) -> Ast.Pcircles(string_mcode dots)
	| Ast.OptParam(param) -> Ast.OptParam(parameterTypeDef param)
	| Ast.UniqueParam(param) -> Ast.UniqueParam(parameterTypeDef param)) in
    paramfn all_functions k p

  and rule_elem re =
    let k re =
      Ast.rewrap re
	(match Ast.unwrap re with
	  Ast.FunHeader(bef,allminus,fi,name,lp,params,rp) ->
	    Ast.FunHeader(bef,allminus,List.map fninfo fi,ident name,
			  string_mcode lp, parameter_dots params,
			  string_mcode rp)
	| Ast.Decl(bef,allminus,decl) ->
	    Ast.Decl(bef,allminus,declaration decl)
	| Ast.SeqStart(brace) -> Ast.SeqStart(string_mcode brace)
	| Ast.SeqEnd(brace) -> Ast.SeqEnd(string_mcode brace)
	| Ast.ExprStatement(exp,sem) ->
	    Ast.ExprStatement (expression exp, string_mcode sem)
	| Ast.IfHeader(iff,lp,exp,rp) ->
	    Ast.IfHeader(string_mcode iff, string_mcode lp, expression exp,
	      string_mcode rp)
	| Ast.Else(els) -> Ast.Else(string_mcode els)
	| Ast.WhileHeader(whl,lp,exp,rp) ->
	    Ast.WhileHeader(string_mcode whl, string_mcode lp, expression exp,
			    string_mcode rp)
	| Ast.DoHeader(d) -> Ast.DoHeader(string_mcode d)
	| Ast.WhileTail(whl,lp,exp,rp,sem) ->
	    Ast.WhileTail(string_mcode whl, string_mcode lp, expression exp,
			  string_mcode rp, string_mcode sem)
	| Ast.ForHeader(fr,lp,e1,sem1,e2,sem2,e3,rp) ->
	    Ast.ForHeader(string_mcode fr, string_mcode lp,
			  get_option expression e1, string_mcode sem1,
			  get_option expression e2, string_mcode sem2,
			  get_option expression e3, string_mcode rp)
	| Ast.IteratorHeader(whl,lp,args,rp) ->
	    Ast.IteratorHeader(ident whl, string_mcode lp,
			       expression_dots args, string_mcode rp)
	| Ast.SwitchHeader(switch,lp,exp,rp) ->
	    Ast.SwitchHeader(string_mcode switch, string_mcode lp,
			     expression exp, string_mcode rp)
	| Ast.Break(br,sem) ->
	    Ast.Break(string_mcode br, string_mcode sem)
	| Ast.Continue(cont,sem) ->
	    Ast.Continue(string_mcode cont, string_mcode sem)
	| Ast.Label(l,dd) -> Ast.Label(ident l, string_mcode dd)
	| Ast.Goto(goto,l,sem) ->
	    Ast.Goto(string_mcode goto,ident l,string_mcode sem)
	| Ast.Return(ret,sem) ->
	    Ast.Return(string_mcode ret, string_mcode sem)
	| Ast.ReturnExpr(ret,exp,sem) ->
	    Ast.ReturnExpr(string_mcode ret, expression exp, string_mcode sem)
	| Ast.MetaStmt(name,keep,seqible,inherited) ->
	    Ast.MetaStmt(meta_mcode name,keep,seqible,inherited)
	| Ast.MetaStmtList(name,keep,inherited) ->
	    Ast.MetaStmtList(meta_mcode name,keep,inherited)
	| Ast.MetaRuleElem(name,keep,inherited) ->
	    Ast.MetaRuleElem(meta_mcode name,keep,inherited)
	| Ast.Exp(exp) -> Ast.Exp(expression exp)
	| Ast.TopExp(exp) -> Ast.TopExp(expression exp)
	| Ast.Ty(ty) -> Ast.Ty(fullType ty)
	| Ast.TopInit(init) -> Ast.TopInit(initialiser init)
	| Ast.Include(inc,name) ->
	    Ast.Include(string_mcode inc,inc_file_mcode name)
	| Ast.DefineHeader(def,id,params) ->
	    Ast.DefineHeader(string_mcode def,ident id,
			     define_parameters params)
	| Ast.Default(def,colon) ->
	    Ast.Default(string_mcode def,string_mcode colon)
	| Ast.Case(case,exp,colon) ->
	    Ast.Case(string_mcode case,expression exp,string_mcode colon)
	| Ast.DisjRuleElem(res) -> Ast.DisjRuleElem(List.map rule_elem res)) in
    rulefn all_functions k re

  (* not parameterizable for now... *)
  and define_parameters p =
    let k p =
      Ast.rewrap p
	(match Ast.unwrap p with
	  Ast.NoParams -> Ast.NoParams
	| Ast.DParams(lp,params,rp) ->
	    Ast.DParams(string_mcode lp,define_param_dots params,
			string_mcode rp)) in
    k p

  and define_param_dots d =
    let k d =
      Ast.rewrap d
	(match Ast.unwrap d with
	  Ast.DOTS(l) -> Ast.DOTS(List.map define_param l)
	| Ast.CIRCLES(l) -> Ast.CIRCLES(List.map define_param l)
	| Ast.STARS(l) -> Ast.STARS(List.map define_param l)) in
    k d

  and define_param p =
    let k p =
      Ast.rewrap p
	(match Ast.unwrap p with
	  Ast.DParam(id) -> Ast.DParam(ident id)
	| Ast.DPComma(comma) -> Ast.DPComma(string_mcode comma)
	| Ast.DPdots(d) -> Ast.DPdots(string_mcode d)
	| Ast.DPcircles(c) -> Ast.DPcircles(string_mcode c)
	| Ast.OptDParam(dp) -> Ast.OptDParam(define_param dp)
	| Ast.UniqueDParam(dp) -> Ast.UniqueDParam(define_param dp)) in
    k p

  and process_bef_aft s =
    Ast.set_dots_bef_aft
      (match Ast.get_dots_bef_aft s with
	Ast.NoDots -> Ast.NoDots
      | Ast.DroppingBetweenDots(stm,ind) ->
	  Ast.DroppingBetweenDots(statement stm,ind)
      | Ast.AddingBetweenDots(stm,ind) ->
	  Ast.AddingBetweenDots(statement stm,ind))
      s

  and statement s =
    let k s =
      Ast.rewrap s
	(match Ast.unwrap s with
	  Ast.Seq(lbrace,decls,body,rbrace) ->
	    Ast.Seq(rule_elem lbrace, statement_dots decls,
		    statement_dots body, rule_elem rbrace)
	| Ast.IfThen(header,branch,aft) ->
	    Ast.IfThen(rule_elem header, statement branch,aft)
	| Ast.IfThenElse(header,branch1,els,branch2,aft) ->
	    Ast.IfThenElse(rule_elem header, statement branch1, rule_elem els,
			   statement branch2, aft)
	| Ast.While(header,body,aft) ->
	    Ast.While(rule_elem header, statement body, aft)
	| Ast.Do(header,body,tail) ->
	    Ast.Do(rule_elem header, statement body, rule_elem tail)
	| Ast.For(header,body,aft) ->
	    Ast.For(rule_elem header, statement body, aft)
	| Ast.Iterator(header,body,aft) ->
	    Ast.Iterator(rule_elem header, statement body, aft)
	| Ast.Switch(header,lb,cases,rb) ->
	    Ast.Switch(rule_elem header,rule_elem lb,
		       List.map case_line cases,rule_elem rb)
	| Ast.Atomic(re) -> Ast.Atomic(rule_elem re)
	| Ast.Disj(stmt_dots_list) ->
	    Ast.Disj (List.map statement_dots stmt_dots_list)
	| Ast.Nest(stmt_dots,whn,multi,bef,aft) ->
	    Ast.Nest(statement_dots stmt_dots,
		     List.map (whencode statement_dots statement) whn,
		     multi,bef,aft)
	| Ast.FunDecl(header,lbrace,decls,body,rbrace) ->
	    Ast.FunDecl(rule_elem header,rule_elem lbrace,
			statement_dots decls,
			statement_dots body, rule_elem rbrace)
	| Ast.Define(header,body) ->
	    Ast.Define(rule_elem header,statement_dots body)
	| Ast.Dots(d,whn,bef,aft) ->
	    Ast.Dots(string_mcode d,
		     List.map (whencode statement_dots statement) whn,bef,aft)
	| Ast.Circles(d,whn,bef,aft) ->
	    Ast.Circles(string_mcode d,
			List.map (whencode statement_dots statement) whn,
			bef,aft)
	| Ast.Stars(d,whn,bef,aft) ->
	    Ast.Stars(string_mcode d,
		      List.map (whencode statement_dots statement) whn,bef,aft)
	| Ast.OptStm(stmt) -> Ast.OptStm(statement stmt)
	| Ast.UniqueStm(stmt) -> Ast.UniqueStm(statement stmt)) in
    let s = stmtfn all_functions k s in
    (* better to do this after, in case there is an equality test on the whole
       statement, eg in free_vars.  equality test would require that this
       subterm not already be changed *)
    process_bef_aft s

  and fninfo = function
      Ast.FStorage(stg) -> Ast.FStorage(storage_mcode stg)
    | Ast.FType(ty) -> Ast.FType(fullType ty)
    | Ast.FInline(inline) -> Ast.FInline(string_mcode inline)
    | Ast.FAttr(attr) -> Ast.FAttr(string_mcode attr)

  and whencode notfn alwaysfn = function
      Ast.WhenNot a -> Ast.WhenNot (notfn a)
    | Ast.WhenAlways a -> Ast.WhenAlways (alwaysfn a)
    | Ast.WhenModifier(x)    -> Ast.WhenModifier(x)
    | Ast.WhenNotTrue(e) -> Ast.WhenNotTrue(rule_elem e)
    | Ast.WhenNotFalse(e) -> Ast.WhenNotFalse(rule_elem e)

  and case_line c =
    let k c =
      Ast.rewrap c
	(match Ast.unwrap c with
	  Ast.CaseLine(header,code) ->
	    Ast.CaseLine(rule_elem header,statement_dots code)
	| Ast.OptCase(case) -> Ast.OptCase(case_line case)) in
    casefn all_functions k c

  and top_level t =
    let k t =
      Ast.rewrap t
	(match Ast.unwrap t with
	  Ast.FILEINFO(old_file,new_file) ->
	    Ast.FILEINFO (string_mcode old_file, string_mcode new_file)
	| Ast.DECL(stmt) -> Ast.DECL(statement stmt)
	| Ast.CODE(stmt_dots) -> Ast.CODE(statement_dots stmt_dots)
	| Ast.ERRORWORDS(exps) -> Ast.ERRORWORDS (List.map expression exps)) in
    topfn all_functions k t

  and anything a =
    let k = function
	(*in many cases below, the thing is not even mcode, so we do nothing*)
	Ast.FullTypeTag(ft) -> Ast.FullTypeTag(fullType ft)
      | Ast.BaseTypeTag(bt) as x -> x
      | Ast.StructUnionTag(su) as x -> x
      | Ast.SignTag(sgn) as x -> x
      | Ast.IdentTag(id) -> Ast.IdentTag(ident id)
      | Ast.ExpressionTag(exp) -> Ast.ExpressionTag(expression exp)
      | Ast.ConstantTag(cst) as x -> x
      | Ast.UnaryOpTag(unop) as x -> x
      | Ast.AssignOpTag(asgnop) as x -> x
      | Ast.FixOpTag(fixop) as x -> x
      | Ast.BinaryOpTag(binop) as x -> x
      | Ast.ArithOpTag(arithop) as x -> x
      | Ast.LogicalOpTag(logop) as x -> x
      | Ast.InitTag(decl) -> Ast.InitTag(initialiser decl)
      | Ast.DeclarationTag(decl) -> Ast.DeclarationTag(declaration decl)
      | Ast.StorageTag(stg) as x -> x
      | Ast.IncFileTag(stg) as x -> x
      | Ast.Rule_elemTag(rule) -> Ast.Rule_elemTag(rule_elem rule)
      | Ast.StatementTag(rule) -> Ast.StatementTag(statement rule)
      | Ast.CaseLineTag(case) -> Ast.CaseLineTag(case_line case)
      | Ast.ConstVolTag(cv) as x -> x
      | Ast.Token(tok,info) as x -> x
      | Ast.Pragma(str) as x -> x
      | Ast.Code(cd) -> Ast.Code(top_level cd)
      | Ast.ExprDotsTag(ed) -> Ast.ExprDotsTag(expression_dots ed)
      | Ast.ParamDotsTag(pd) -> Ast.ParamDotsTag(parameter_dots pd)
      | Ast.StmtDotsTag(sd) -> Ast.StmtDotsTag(statement_dots sd)
      | Ast.DeclDotsTag(sd) -> Ast.DeclDotsTag(declaration_dots sd)
      | Ast.TypeCTag(ty) -> Ast.TypeCTag(typeC ty)
      | Ast.ParamTag(param) -> Ast.ParamTag(parameterTypeDef param)
      | Ast.SgrepStartTag(tok) as x -> x
      | Ast.SgrepEndTag(tok) as x -> x in
    anyfn all_functions k a

  and all_functions =
    {rebuilder_ident = ident;
      rebuilder_expression = expression;
      rebuilder_fullType= fullType;
      rebuilder_typeC = typeC;
      rebuilder_declaration = declaration;
      rebuilder_initialiser = initialiser;
      rebuilder_parameter = parameterTypeDef;
      rebuilder_parameter_list = parameter_dots;
      rebuilder_rule_elem = rule_elem;
      rebuilder_statement = statement;
      rebuilder_case_line = case_line;
      rebuilder_top_level = top_level;
      rebuilder_expression_dots = expression_dots;
      rebuilder_statement_dots = statement_dots;
      rebuilder_declaration_dots = declaration_dots;
      rebuilder_define_param_dots = define_param_dots;
      rebuilder_define_param = define_param;
      rebuilder_define_parameters = define_parameters;
      rebuilder_anything = anything} in
  all_functions
