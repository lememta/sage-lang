import Sage.AST

namespace Sage

-- ═══════════════════════════════════════════════════════════════════
-- Verification Engine for Machine-Verifiable Contracts
-- Implements: 8.1 Refinement Types, 8.2 Pre/Post Conditions,
--   8.3 Data Structure Invariants, 8.4 Effect Tracking,
--   8.5 Termination Proofs
-- ═══════════════════════════════════════════════════════════════════

-- ─── Helpers ─────────────────────────────────────────────────────

def VerifyResult.ok : VerifyResult := { messages := [] }

def VerifyResult.error (loc msg : String) : VerifyResult :=
  { messages := [{ severity := .error, location := loc, message := msg }] }

def VerifyResult.warning (loc msg : String) : VerifyResult :=
  { messages := [{ severity := .warning, location := loc, message := msg }] }

def VerifyResult.info (loc msg : String) : VerifyResult :=
  { messages := [{ severity := .info, location := loc, message := msg }] }

def VerifyResult.merge (a b : VerifyResult) : VerifyResult :=
  { messages := a.messages ++ b.messages }

def VerifyResult.hasErrors (r : VerifyResult) : Bool :=
  r.messages.any (fun m => m.severity == .error)

instance : Append VerifyResult where
  append := VerifyResult.merge

-- Verification environment
structure VerifyEnv where
  bindings : List (String × SageType) := []
  constraints : List Expr := []
  typeInvariants : List (String × List Expr) := []
  functionEffects : List (String × List Effect) := []
  deriving Inhabited

-- concatMap: flatMap/bind for lists (foldl-based for Lean 4 compatibility)
def concatMap {α β : Type} (xs : List α) (f : α → List β) : List β :=
  xs.foldl (fun acc x => acc ++ f x) []

-- ─── Expression Analysis Utilities ──────────────────────────────

-- Extract free variable names from an expression
partial def freeVars : Expr → List String
  | .ident name => [name]
  | .lit _ => []
  | .num _ => []
  | .bool _ => []
  | .binOp _ lhs rhs => freeVars lhs ++ freeVars rhs
  | .unOp _ operand => freeVars operand
  | .call name args => [name] ++ concatMap args freeVars
  | .member obj _ => freeVars obj
  | .list elems => concatMap elems freeVars
  | .structLit fields => concatMap fields (fun (_, e) => freeVars e)
  | .forall_ var _ body => (freeVars body).filter (· != var)
  | .exists_ var _ body => (freeVars body).filter (· != var)
  | .implies lhs rhs => freeVars lhs ++ freeVars rhs
  | .elementOf elem set => freeVars elem ++ freeVars set

-- Check if expression references a specific variable
def referencesVar (expr : Expr) (name : String) : Bool :=
  (freeVars expr).any (· == name)

-- Extract all function call names from an expression
partial def extractCallsExpr : Expr → List String
  | .call name args => [name] ++ concatMap args extractCallsExpr
  | .binOp _ lhs rhs => extractCallsExpr lhs ++ extractCallsExpr rhs
  | .unOp _ operand => extractCallsExpr operand
  | .member obj _ => extractCallsExpr obj
  | .implies lhs rhs => extractCallsExpr lhs ++ extractCallsExpr rhs
  | .forall_ _ _ body => extractCallsExpr body
  | .exists_ _ _ body => extractCallsExpr body
  | .elementOf elem set => extractCallsExpr elem ++ extractCallsExpr set
  | .list elems => concatMap elems extractCallsExpr
  | .structLit fields => concatMap fields (fun (_, e) => extractCallsExpr e)
  | _ => []

-- Extract all function call names from a statement
partial def extractCallsStmt : Stmt → List String
  | .naturalText _ _ => []
  | .letBind _ _ expr => extractCallsExpr expr
  | .ret expr => extractCallsExpr expr
  | .if_ cond thenBranch elseBranch =>
    extractCallsExpr cond ++
    concatMap thenBranch extractCallsStmt ++
    (match elseBranch with | some stmts => concatMap stmts extractCallsStmt | none => [])
  | .expr e => extractCallsExpr e

-- Detect if two simple comparison expressions are contradictory
def isContradictoryPair (a b : Expr) : Bool :=
  match a, b with
  | .binOp ">" (.ident n1) _, .binOp "<" (.ident n2) _ => n1 == n2
  | .binOp "<" (.ident n1) _, .binOp ">" (.ident n2) _ => n1 == n2
  | .binOp ">=" (.ident n1) _, .binOp "<" (.ident n2) _ => n1 == n2
  | .binOp "<=" (.ident n1) _, .binOp ">" (.ident n2) _ => n1 == n2
  | .binOp "==" (.ident n1) (.num v1), .binOp "==" (.ident n2) (.num v2) =>
    n1 == n2 && v1 != v2
  | .binOp "==" (.ident n1) (.lit v1), .binOp "==" (.ident n2) (.lit v2) =>
    n1 == n2 && v1 != v2
  | .binOp "==" (.ident n1) (.bool v1), .binOp "==" (.ident n2) (.bool v2) =>
    n1 == n2 && v1 != v2
  | _, _ => false

-- Check a list of expressions for pairwise contradictions
def findContradictions (exprs : List Expr) : Option (Expr × Expr) :=
  let pairs := concatMap exprs (fun a => exprs.map (fun b => (a, b)))
  pairs.find? (fun (a, b) => !(a == b) && isContradictoryPair a b)

-- Check if an expression is trivially always true
def isTriviallyTrue : Expr → Bool
  | .bool true => true
  | .binOp "==" e1 e2 => e1 == e2
  | _ => false

-- Check if an expression is trivially always false
def isTriviallyFalse : Expr → Bool
  | .bool false => true
  | _ => false

-- ═══════════════════════════════════════════════════════════════════
-- 8.1 Refinement Type Verification
-- ═══════════════════════════════════════════════════════════════════

partial def verifyRefinementType (env : VerifyEnv) (ty : SageType) (loc : String) : VerifyResult :=
  match ty with
  | .refined varName baseType predicate =>
    let r1 := if varName.isEmpty then
        VerifyResult.error loc "Refinement type has empty bound variable name"
      else VerifyResult.ok
    let r2 := match baseType with
      | .name n => if n.isEmpty then
          VerifyResult.error loc "Refinement type has empty base type name"
        else VerifyResult.ok
      | _ => VerifyResult.ok
    let r3 := if !varName.isEmpty && !referencesVar predicate varName then
        VerifyResult.warning loc
          s!"Refinement predicate does not reference bound variable '{varName}'"
      else VerifyResult.ok
    let r4 := if isTriviallyTrue predicate then
        VerifyResult.warning loc
          "Refinement predicate is trivially true — refinement has no effect"
      else VerifyResult.ok
    let r5 := if isTriviallyFalse predicate then
        VerifyResult.error loc
          "Refinement predicate is trivially false — type is uninhabitable"
      else VerifyResult.ok
    let r6 := verifyRefinementType env baseType loc
    r1 ++ r2 ++ r3 ++ r4 ++ r5 ++ r6
  | .generic _ args =>
    args.foldl (fun acc arg => acc ++ verifyRefinementType env arg loc) VerifyResult.ok
  | .struct fields =>
    fields.foldl (fun acc (_, fieldTy) => acc ++ verifyRefinementType env fieldTy loc) VerifyResult.ok
  | .union variants =>
    variants.foldl (fun acc v => acc ++ verifyRefinementType env v loc) VerifyResult.ok
  | .arrow params ret =>
    let paramResult := params.foldl (fun acc p => acc ++ verifyRefinementType env p loc) VerifyResult.ok
    paramResult ++ verifyRefinementType env ret loc
  | .name _ => VerifyResult.ok

-- ═══════════════════════════════════════════════════════════════════
-- 8.2 Pre/Post Condition Verification
-- ═══════════════════════════════════════════════════════════════════

def verifyContracts (_env : VerifyEnv) (func : Function) (loc : String) : VerifyResult :=
  let paramNames := func.params.map (·.1)

  -- Check preconditions for contradictions
  let r1 := if func.requires.length > 1 then
    match findContradictions func.requires with
    | some _ => VerifyResult.error loc
        s!"Function '{func.name}' has contradictory preconditions — no input can satisfy all @req"
    | none => VerifyResult.ok
  else VerifyResult.ok

  -- Check preconditions reference valid parameters
  let r2 := if !paramNames.isEmpty then
    func.requires.foldl (fun acc req =>
      match req with
      | .lit _ => acc  -- String literals are natural language
      | _ =>
        let vars := freeVars req
        vars.foldl (fun innerAcc v =>
          if !paramNames.any (· == v) && v != "result" then
            innerAcc ++ VerifyResult.warning loc
              s!"Precondition in '{func.name}' references '{v}' which is not a declared parameter"
          else innerAcc
        ) acc
    ) VerifyResult.ok
  else VerifyResult.ok

  -- Check postconditions for contradictions
  let r3 := if func.ensures.length > 1 then
    match findContradictions func.ensures with
    | some _ => VerifyResult.error loc
        s!"Function '{func.name}' has contradictory postconditions"
    | none => VerifyResult.ok
  else VerifyResult.ok

  -- Check postconditions reference valid names
  let r4 := if !paramNames.isEmpty then
    func.ensures.foldl (fun acc ens =>
      match ens with
      | .lit _ => acc
      | _ =>
        let vars := freeVars ens
        vars.foldl (fun innerAcc v =>
          if !paramNames.any (· == v) && v != "result" then
            innerAcc ++ VerifyResult.warning loc
              s!"Postcondition in '{func.name}' references '{v}' which is not a parameter or 'result'"
          else innerAcc
        ) acc
    ) VerifyResult.ok
  else VerifyResult.ok

  -- Check if all preconditions are trivially false
  let r5 := if !func.requires.isEmpty && func.requires.all isTriviallyFalse then
    VerifyResult.warning loc
      s!"All preconditions of '{func.name}' are trivially false — function is unreachable"
  else VerifyResult.ok

  -- Check simple implication: postcondition directly matches a precondition
  let r6 := func.ensures.foldl (fun acc ens =>
    match ens with
    | .lit _ => acc
    | _ =>
      if func.requires.any (fun req => req == ens) then
        acc ++ VerifyResult.info loc
          s!"Postcondition in '{func.name}' is directly implied by a precondition ✓"
      else acc
  ) VerifyResult.ok

  -- Report contract summary
  let r7 := if !func.requires.isEmpty || !func.ensures.isEmpty then
    VerifyResult.info loc
      s!"'{func.name}': {func.requires.length} precondition(s), {func.ensures.length} postcondition(s) checked"
  else VerifyResult.ok

  r1 ++ r2 ++ r3 ++ r4 ++ r5 ++ r6 ++ r7

-- ═══════════════════════════════════════════════════════════════════
-- 8.3 Data Structure Invariant Verification
-- ═══════════════════════════════════════════════════════════════════

def verifyInvariants (_env : VerifyEnv) (typeDecl : TypeDecl) (functions : List Function) (loc : String) : VerifyResult :=
  -- Check invariant consistency
  let r1 := if typeDecl.invariants.length > 1 then
    match findContradictions typeDecl.invariants with
    | some _ => VerifyResult.error loc
        s!"Type '{typeDecl.name}' has contradictory invariants"
    | none => VerifyResult.ok
  else VerifyResult.ok

  -- Check each invariant for triviality
  let r2 := typeDecl.invariants.foldl (fun acc inv =>
    let trivTrue := if isTriviallyTrue inv then
      VerifyResult.warning loc
        s!"Invariant on '{typeDecl.name}' is trivially true — provides no constraint"
    else VerifyResult.ok
    let trivFalse := if isTriviallyFalse inv then
      VerifyResult.error loc
        s!"Invariant on '{typeDecl.name}' is trivially false — type cannot be constructed"
    else VerifyResult.ok
    acc ++ trivTrue ++ trivFalse
  ) VerifyResult.ok

  -- Check refinement consistency
  let r3 := match typeDecl.definition with
    | .refined _ _ predicate =>
      typeDecl.invariants.foldl (fun acc inv =>
        if isContradictoryPair predicate inv then
          acc ++ VerifyResult.error loc
            s!"Invariant on '{typeDecl.name}' contradicts its refinement predicate"
        else acc
      ) VerifyResult.ok
    | _ => VerifyResult.ok

  -- Check functions returning this type preserve invariants
  let typeName := typeDecl.name
  let r4 := if !typeDecl.invariants.isEmpty then
    functions.foldl (fun acc func =>
      let returnsType := match func.returnType with
        | .name n => n == typeName
        | .generic n _ => n == typeName
        | _ => false
      if returnsType && func.ensures.isEmpty then
        acc ++ VerifyResult.warning loc
          s!"Function '{func.name}' returns '{typeName}' which has invariants, but declares no @ens — invariant preservation is unverified"
      else acc
    ) VerifyResult.ok
  else VerifyResult.ok

  -- Summary
  let r5 := if !typeDecl.invariants.isEmpty then
    VerifyResult.info loc
      s!"'{typeDecl.name}': {typeDecl.invariants.length} invariant(s) checked"
  else VerifyResult.ok

  r1 ++ r2 ++ r3 ++ r4 ++ r5

-- ═══════════════════════════════════════════════════════════════════
-- 8.4 Effect Tracking Verification
-- ═══════════════════════════════════════════════════════════════════

def verifyEffects (env : VerifyEnv) (func : Function) (loc : String) : VerifyResult :=
  let hasPure := func.effects.any (· == Effect.pure)
  let hasIO := func.effects.any (· == Effect.io)
  let hasMutation := func.effects.any (· == Effect.mutation)
  let hasException := func.effects.any (· == Effect.exception)
  let hasDiverge := func.effects.any (· == Effect.diverge)

  -- Check contradictory effects
  let r1 := if hasPure then
    let e1 := if hasIO then
      VerifyResult.error loc s!"Function '{func.name}' declares both @pure and @effect IO — contradictory"
    else VerifyResult.ok
    let e2 := if hasMutation then
      VerifyResult.error loc s!"Function '{func.name}' declares both @pure and @effect Mutation — contradictory"
    else VerifyResult.ok
    let e3 := if hasException then
      VerifyResult.error loc s!"Function '{func.name}' declares both @pure and @effect Exception — contradictory"
    else VerifyResult.ok
    let e4 := if hasDiverge then
      VerifyResult.error loc s!"Function '{func.name}' declares both @pure and @effect Diverge — contradictory"
    else VerifyResult.ok
    e1 ++ e2 ++ e3 ++ e4
  else VerifyResult.ok

  -- Check duplicate effects
  let r2 := if func.effects.eraseDups.length < func.effects.length then
    VerifyResult.warning loc s!"Function '{func.name}' has duplicate effect declarations"
  else VerifyResult.ok

  -- Check calls to effectful functions
  let bodyCallNames := concatMap func.body extractCallsStmt
  let r3 := bodyCallNames.foldl (fun acc callName =>
    match env.functionEffects.find? (fun (n, _) => n == callName) with
    | some (_, calledEffects) =>
      let callCheck := if hasPure && calledEffects.any (· != Effect.pure) then
        VerifyResult.error loc
          s!"Pure function '{func.name}' calls effectful function '{callName}'"
      else VerifyResult.ok
      let coverCheck := if !func.effects.isEmpty && !hasPure then
        calledEffects.foldl (fun innerAcc eff =>
          if eff != Effect.pure && !func.effects.any (· == eff) then
            innerAcc ++ VerifyResult.warning loc
              s!"Function '{func.name}' calls '{callName}' which has effects not covered by declared effects"
          else innerAcc
        ) VerifyResult.ok
      else VerifyResult.ok
      acc ++ callCheck ++ coverCheck
    | none => acc
  ) VerifyResult.ok

  -- Effect summary
  let r4 := if !func.effects.isEmpty then
    let effectNames := func.effects.map (fun e => match e with
      | .io => "IO" | .mutation => "Mutation" | .exception => "Exception"
      | .diverge => "Diverge" | .pure => "Pure")
    VerifyResult.info loc
      s!"'{func.name}' effects: [{String.intercalate ", " effectNames}]"
  else VerifyResult.ok

  r1 ++ r2 ++ r3 ++ r4

-- ═══════════════════════════════════════════════════════════════════
-- 8.5 Termination Proof Verification
-- ═══════════════════════════════════════════════════════════════════

-- Detect if a function is recursive (calls itself in body or contracts)
def isRecursive (func : Function) : Bool :=
  let bodyCalls := concatMap func.body extractCallsStmt
  let contractCalls := concatMap func.requires extractCallsExpr ++
                       concatMap func.ensures extractCallsExpr
  let allCalls := bodyCalls ++ contractCalls
  allCalls.any (· == func.name)

def verifyTermination (_env : VerifyEnv) (func : Function) (loc : String) : VerifyResult :=
  let recursive := isRecursive func

  if recursive then
    match func.decreases with
    | some measure =>
      let measureVars := freeVars measure
      let paramNames := func.params.map (·.1)

      -- Check measure is not a constant
      let r1 := match measure with
        | .num _ => VerifyResult.error loc
            s!"Termination measure for '{func.name}' is a numeric literal — will not decrease"
        | .bool _ => VerifyResult.error loc
            s!"Termination measure for '{func.name}' is a boolean literal — invalid measure"
        | .lit _ => VerifyResult.error loc
            s!"Termination measure for '{func.name}' is a string literal — invalid measure"
        | _ => VerifyResult.ok

      -- Check measure references variables
      let r2 := if measureVars.isEmpty then
        VerifyResult.error loc
          s!"Termination measure for '{func.name}' is a constant — does not decrease"
      else VerifyResult.ok

      -- Check measure references parameters
      let r3 := if !paramNames.isEmpty && !measureVars.isEmpty then
        let refsParam := measureVars.any (fun v => paramNames.any (· == v))
        if refsParam then
          VerifyResult.info loc
            s!"Termination measure for '{func.name}' references parameter — structural decrease plausible ✓"
        else
          VerifyResult.warning loc
            s!"Termination measure for '{func.name}' does not reference any declared parameter"
      else if !measureVars.isEmpty then
        VerifyResult.info loc
          s!"Termination measure declared for recursive function '{func.name}'"
      else VerifyResult.ok

      r1 ++ r2 ++ r3

    | none =>
      VerifyResult.error loc
        s!"Recursive function '{func.name}' has no @decreases annotation — termination is unproven"
  else
    match func.decreases with
    | some _ =>
      VerifyResult.warning loc
        s!"Non-recursive function '{func.name}' has @decreases — annotation is unnecessary"
    | none => VerifyResult.ok

-- ═══════════════════════════════════════════════════════════════════
-- Program-Level Verification (Orchestrator)
-- ═══════════════════════════════════════════════════════════════════

def verifyFunction (env : VerifyEnv) (func : Function) (moduleName : String) : VerifyResult :=
  let loc := s!"{moduleName}.{func.name}"
  -- 8.1: Verify refinement types in return type and parameters
  let r1 := verifyRefinementType env func.returnType loc
  let r2 := func.params.foldl (fun acc (_, paramTy) =>
    acc ++ verifyRefinementType env paramTy loc) VerifyResult.ok
  -- 8.2: Verify pre/post conditions
  let r3 := verifyContracts env func loc
  -- 8.4: Verify effects
  let r4 := verifyEffects env func loc
  -- 8.5: Verify termination
  let r5 := verifyTermination env func loc
  r1 ++ r2 ++ r3 ++ r4 ++ r5

def verifyModule (env : VerifyEnv) (mod : Module) : VerifyResult :=
  -- Build environment with this module's function effects
  let modEnv : VerifyEnv := {
    env with
    functionEffects := env.functionEffects ++
      mod.functions.map (fun f => (f.name, f.effects))
    typeInvariants := env.typeInvariants ++
      mod.types.filterMap (fun t =>
        if t.invariants.isEmpty then none
        else some (t.name, t.invariants))
  }

  -- 8.1 + 8.3: Verify type declarations
  let r1 := mod.types.foldl (fun acc typeDecl =>
    let loc := s!"{mod.name}.{typeDecl.name}"
    acc ++ verifyRefinementType modEnv typeDecl.definition loc
        ++ verifyInvariants modEnv typeDecl mod.functions loc
  ) VerifyResult.ok

  -- 8.2 + 8.4 + 8.5: Verify functions
  let r2 := mod.functions.foldl (fun acc func =>
    acc ++ verifyFunction modEnv func mod.name
  ) VerifyResult.ok

  r1 ++ r2

def verifyProgram (prog : Program) : VerifyResult :=
  -- Build global environment with all function effects
  let globalEnv : VerifyEnv := {
    functionEffects := concatMap prog.modules (fun m =>
      m.functions.map (fun f => (f.name, f.effects)))
    typeInvariants := concatMap prog.modules (fun m =>
      m.types.filterMap (fun t =>
        if t.invariants.isEmpty then none
        else some (t.name, t.invariants)))
  }
  prog.modules.foldl (fun acc mod => acc ++ verifyModule globalEnv mod) VerifyResult.ok

end Sage
