namespace Sage

-- 8.4 Effect Tracking: Effect types for functions
inductive Effect where
  | io        -- File/network/system IO
  | mutation  -- Mutable state modification
  | exception -- Can throw/propagate exceptions
  | diverge   -- May not terminate
  | pure      -- No effects (explicit purity)
  deriving Repr, BEq, Inhabited

-- Verification status for contracts, invariants, termination
inductive VerifyStatus where
  | verified                       -- Machine-verified to hold
  | unverified                     -- Not yet checked
  | failed : String → VerifyStatus -- Failed with reason
  deriving Repr, BEq, Inhabited

-- Severity for verification messages
inductive Severity where
  | error | warning | info
  deriving Repr, BEq, Inhabited

-- A single verification message
structure VerifyMessage where
  severity : Severity
  location : String
  message : String
  deriving Repr, Inhabited

-- Aggregated verification results
structure VerifyResult where
  messages : List VerifyMessage := []
  deriving Inhabited

-- 8.2 Pre/Post Conditions: Contract kind
inductive ContractKind where
  | requires   -- Precondition
  | ensures    -- Postcondition
  | invariant  -- Invariant (on data structure or loop)
  | assertion  -- Inline assertion
  deriving Repr, BEq, Inhabited

-- ─── Expressions (defined BEFORE SageType to avoid mutual recursion) ────

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
  -- 8.2/8.3 Logical quantifiers for machine-verifiable contracts
  -- Type annotations use String (type name) to avoid mutual recursion with SageType
  | forall_ : String → String → Expr → Expr       -- ∀ x : TypeName, P(x)
  | exists_ : String → String → Expr → Expr       -- ∃ x : TypeName, P(x)
  | implies : Expr → Expr → Expr                   -- P ⟹ Q
  | elementOf : Expr → Expr → Expr                 -- x ∈ S
  deriving Repr, BEq, Inhabited

-- ─── Types (can reference Expr since Expr is defined above) ─────────────

-- 8.1 Refinement Types: Types with predicates
inductive SageType where
  | name : String → SageType
  | generic : String → List SageType → SageType
  | struct : List (String × SageType) → SageType
  | union : List SageType → SageType
  | arrow : List SageType → SageType → SageType
  | refined : String → SageType → Expr → SageType  -- { x : T | P(x) }
  deriving Repr, BEq, Inhabited

-- ─── Statements ─────────────────────────────────────────────────────────

inductive Stmt where
  | naturalText : String → Bool → Stmt
  | letBind : String → Option SageType → Expr → Stmt
  | ret : Expr → Stmt
  | if_ : Expr → List Stmt → Option (List Stmt) → Stmt
  | expr : Expr → Stmt
  deriving Repr, Inhabited

-- 8.2 Machine-verifiable contract
structure Contract where
  kind : ContractKind
  expr : Expr
  description : Option String := none
  status : VerifyStatus := .unverified
  deriving Repr, Inhabited

-- Function declaration with verification features
structure Function where
  name : String
  params : List (String × SageType)
  returnType : SageType
  requires : List Expr := []              -- backward compat: raw @req exprs
  ensures : List Expr := []               -- backward compat: raw @ens exprs
  contracts : List Contract := []         -- 8.2 structured contracts
  effects : List Effect := []             -- 8.4 declared effects
  decreases : Option Expr := none         -- 8.5 termination measure
  body : List Stmt := []
  deriving Repr, Inhabited

-- Type declaration with invariants
structure TypeDecl where
  name : String
  definition : SageType
  invariants : List Expr := []            -- 8.3 data structure invariants
  deriving Repr, Inhabited

-- Module
structure Module where
  name : String
  imports : List String := []
  types : List TypeDecl := []
  functions : List Function := []
  naturalText : List String := []
  deriving Repr, Inhabited

-- Program
structure Program where
  modules : List Module
  deriving Repr, Inhabited

end Sage
