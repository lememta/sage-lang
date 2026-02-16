namespace Sage

inductive SageType where
  | name : String → SageType
  | generic : String → List SageType → SageType
  | struct : List (String × SageType) → SageType
  | union : List SageType → SageType
  | arrow : List SageType → SageType → SageType
  deriving Repr, BEq, Inhabited

inductive Expr where
  | lit : String → Expr
  | num : Float → Expr
  | bool : Bool → Expr
  | ident : String → Expr
  | binOp : String → Expr → Expr → Expr
  | unOp : String → Expr → Expr
  | call : String → List Expr → Expr
  | member : Expr → String → Expr
  | list : List Expr → Expr
  | structLit : List (String × Expr) → Expr
  deriving Repr, Inhabited

inductive Stmt where
  | naturalText : String → Bool → Stmt
  | letBind : String → Option SageType → Expr → Stmt
  | ret : Expr → Stmt
  | if_ : Expr → List Stmt → Option (List Stmt) → Stmt
  | expr : Expr → Stmt
  deriving Repr, Inhabited

structure Function where
  name : String
  params : List (String × SageType)
  returnType : SageType
  requires : List Expr := []
  ensures : List Expr := []
  body : List Stmt := []
  deriving Repr, Inhabited

structure TypeDecl where
  name : String
  definition : SageType
  deriving Repr, Inhabited

structure Module where
  name : String
  imports : List String := []
  types : List TypeDecl := []
  functions : List Function := []
  naturalText : List String := []
  deriving Repr, Inhabited

structure Program where
  modules : List Module
  deriving Repr, Inhabited

end Sage
