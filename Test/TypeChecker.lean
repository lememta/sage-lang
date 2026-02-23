import Sage.Token
import Sage.AST
import Sage.Lexer
import Sage.Parser
import Sage.TypeCheck
import Sage.Verify

namespace SageTest.TypeChecker

-- Test result type
inductive TestResult where
  | pass : TestResult
  | fail : String → TestResult

-- Test assertion utilities
def assertEqual (a b : α) [BEq α] [Repr α] (message : String := "Assertion failed") : TestResult :=
  if a == b then TestResult.pass else TestResult.fail s!"{message}: expected {repr b}, got {repr a}"

def assertOk (result : Except String Unit) (message : String := "Expected Ok") : TestResult :=
  match result with
  | Except.ok _ => TestResult.pass
  | Except.error err => TestResult.fail s!"{message}: {err}"

def assertError (result : Except String Unit) (message : String := "Expected Error") : TestResult :=
  match result with
  | Except.error _ => TestResult.pass
  | Except.ok _ => TestResult.fail s!"{message}: Expected error but got success"

-- Test utilities
def typeCheckFromString (input : String) : Except String Unit :=
  let tokens := Sage.tokenize input
  match Sage.parse tokens with
  | some prog => Sage.typeCheck prog
  | none => Except.error "Parsing failed"

-- Basic type checking tests
def basicTests : List (String × (Unit → TestResult)) := [
  ("Empty program", fun _ =>
    let prog : Sage.Program := ⟨[]⟩
    assertOk (Sage.typeCheck prog) "Empty program should pass type checking"),

  ("Simple valid module", fun _ =>
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [],
      functions := [],
      naturalText := ["Test module"]
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Simple module should pass type checking"),

  ("Module with empty name should fail", fun _ =>
    let module : Sage.Module := {
      name := "",
      imports := [],
      types := [],
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertError (Sage.typeCheck prog) "Module with empty name should fail")
]

def typeDeclarationTests : List (String × (Unit → TestResult)) := [
  ("Valid type declaration", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "User",
      definition := Sage.SageType.name "String"
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [typeDecl],
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Valid type declaration should pass"),

  ("Type with empty name should fail", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "",
      definition := Sage.SageType.name "String"
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [typeDecl],
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertError (Sage.typeCheck prog) "Type with empty name should fail"),

  ("Struct type declaration", fun _ =>
    let structType := Sage.SageType.struct [("name", Sage.SageType.name "String")]
    let typeDecl : Sage.TypeDecl := {
      name := "User",
      definition := structType
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [typeDecl],
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Struct type should pass type checking")
]

def functionTests : List (String × (Unit → TestResult)) := [
  ("Valid function declaration", fun _ =>
    let func : Sage.Function := {
      name := "greet",
      params := [],
      returnType := Sage.SageType.name "String",
      requires := [],
      ensures := [],
      body := []
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [],
      functions := [func],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Valid function should pass type checking"),

  ("Function with empty name should fail", fun _ =>
    let func : Sage.Function := {
      name := "",
      params := [],
      returnType := Sage.SageType.name "String",
      requires := [],
      ensures := [],
      body := []
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [],
      functions := [func],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertError (Sage.typeCheck prog) "Function with empty name should fail"),

  ("Function with parameters", fun _ =>
    let func : Sage.Function := {
      name := "login",
      params := [("email", Sage.SageType.name "String"), ("password", Sage.SageType.name "String")],
      returnType := Sage.SageType.name "Bool",
      requires := [],
      ensures := [],
      body := []
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [],
      functions := [func],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Function with parameters should pass"),

  ("Function with contracts", fun _ =>
    let requirement := Sage.Expr.lit "email is valid"
    let ensures := Sage.Expr.lit "result indicates success or failure"
    let func : Sage.Function := {
      name := "validate",
      params := [("email", Sage.SageType.name "String")],
      returnType := Sage.SageType.name "Bool",
      requires := [requirement],
      ensures := [ensures],
      body := []
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [],
      functions := [func],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Function with contracts should pass")
]

def integrationTests : List (String × (Unit → TestResult)) := [
  ("Complete module from string", fun _ =>
    assertOk (typeCheckFromString "@mod test \"Test module\"") "Complete module should pass"),

  ("Module with type and function", fun _ =>
    let input := "@mod auth @type User = String @fn login -> Bool"
    assertOk (typeCheckFromString input) "Module with type and function should pass"),

  ("Natural language only", fun _ =>
    assertOk (typeCheckFromString "\"This is a natural language specification\"") "Natural language should pass")
]

def edgeCaseTests : List (String × (Unit → TestResult)) := [
  ("Multiple modules", fun _ =>
    let module1 : Sage.Module := {
      name := "module1",
      imports := [], types := [], functions := [], naturalText := []
    }
    let module2 : Sage.Module := {
      name := "module2",
      imports := [], types := [], functions := [], naturalText := []
    }
    let prog : Sage.Program := ⟨[module1, module2]⟩
    assertOk (Sage.typeCheck prog) "Multiple modules should pass"),

  ("Complex type definitions", fun _ =>
    let genericType := Sage.SageType.generic "List" [Sage.SageType.name "String"]
    let typeDecl : Sage.TypeDecl := {
      name := "StringList",
      definition := genericType
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [typeDecl],
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Complex type definitions should pass"),

  ("Union types", fun _ =>
    let unionType := Sage.SageType.union [Sage.SageType.name "String", Sage.SageType.name "Int"]
    let typeDecl : Sage.TypeDecl := {
      name := "StringOrInt",
      definition := unionType
    }
    let module : Sage.Module := {
      name := "test",
      imports := [],
      types := [typeDecl],
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Union types should pass")
]

-- Performance tests (basic)
def performanceTests : List (String × (Unit → TestResult)) := [
  ("Large number of types", fun _ =>
    -- Create 100 type declarations
    let types := List.range 100 |>.map (fun i =>
      { name := s!"Type{i}", definition := Sage.SageType.name "String" : Sage.TypeDecl })
    let module : Sage.Module := {
      name := "large_module",
      imports := [],
      types := types,
      functions := [],
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Large number of types should pass"),

  ("Large number of functions", fun _ =>
    -- Create 50 function declarations
    let functions := List.range 50 |>.map (fun i =>
      { name := s!"func{i}",
        params := [],
        returnType := Sage.SageType.name "String",
        requires := [], ensures := [], body := [] : Sage.Function })
    let module : Sage.Module := {
      name := "large_module",
      imports := [],
      types := [],
      functions := functions,
      naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    assertOk (Sage.typeCheck prog) "Large number of functions should pass")
]

-- ═══ Machine-Verifiable Contract Tests ═══

-- 8.1 Refinement type verification tests
def refinementTypeVerifyTests : List (String × (Unit → TestResult)) := [
  ("Refinement type with valid predicate", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "PosInt",
      definition := Sage.SageType.refined "x" (Sage.SageType.name "Int")
        (Sage.Expr.binOp ">" (Sage.Expr.ident "x") (Sage.Expr.num 0.0))
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [typeDecl], functions := [], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then
      TestResult.fail "Valid refinement type should not produce errors"
    else TestResult.pass),

  ("Refinement type with trivially false predicate", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "Empty",
      definition := Sage.SageType.refined "x" (Sage.SageType.name "Int") (Sage.Expr.bool false)
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [typeDecl], functions := [], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then TestResult.pass
    else TestResult.fail "Trivially false refinement should produce error"),

  ("Refinement type with trivially true predicate", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "AnyInt",
      definition := Sage.SageType.refined "x" (Sage.SageType.name "Int") (Sage.Expr.bool true)
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [typeDecl], functions := [], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .warning) then TestResult.pass
    else TestResult.fail "Trivially true refinement should produce warning")
]

-- 8.2 Contract verification tests
def contractVerifyTests : List (String × (Unit → TestResult)) := [
  ("Function with valid contracts", fun _ =>
    let func : Sage.Function := {
      name := "validate",
      params := [("email", Sage.SageType.name "String")],
      returnType := Sage.SageType.name "Bool",
      requires := [Sage.Expr.lit "email is valid"],
      ensures := [Sage.Expr.lit "result indicates success or failure"],
      body := []
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then
      TestResult.fail "Valid contracts should not produce errors"
    else TestResult.pass),

  ("Function with contradictory preconditions", fun _ =>
    let func : Sage.Function := {
      name := "check",
      params := [("x", Sage.SageType.name "Int")],
      returnType := Sage.SageType.name "Bool",
      requires := [
        Sage.Expr.binOp ">" (Sage.Expr.ident "x") (Sage.Expr.num 5.0),
        Sage.Expr.binOp "<" (Sage.Expr.ident "x") (Sage.Expr.num 3.0)
      ],
      ensures := [], body := []
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then TestResult.pass
    else TestResult.fail "Contradictory preconditions should produce error")
]

-- 8.3 Invariant verification tests
def invariantVerifyTests : List (String × (Unit → TestResult)) := [
  ("Type with valid invariant", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "Balance",
      definition := Sage.SageType.name "Int",
      invariants := [Sage.Expr.binOp ">=" (Sage.Expr.ident "balance") (Sage.Expr.num 0.0)]
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [typeDecl], functions := [], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then
      TestResult.fail "Valid invariant should not produce errors"
    else TestResult.pass),

  ("Function returning invariant-bearing type without postcondition", fun _ =>
    let typeDecl : Sage.TypeDecl := {
      name := "Balance",
      definition := Sage.SageType.name "Int",
      invariants := [Sage.Expr.binOp ">=" (Sage.Expr.ident "balance") (Sage.Expr.num 0.0)]
    }
    let func : Sage.Function := {
      name := "withdraw",
      params := [], returnType := Sage.SageType.name "Balance",
      requires := [], ensures := [], body := []
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [typeDecl], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .warning) then TestResult.pass
    else TestResult.fail "Missing postcondition on invariant-bearing return type should warn")
]

-- 8.4 Effect tracking verification tests
def effectVerifyTests : List (String × (Unit → TestResult)) := [
  ("Function with valid IO effect", fun _ =>
    let func : Sage.Function := {
      name := "readFile",
      params := [], returnType := Sage.SageType.name "String",
      requires := [], ensures := [], body := [],
      effects := [Sage.Effect.io]
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then
      TestResult.fail "Valid IO effect should not produce errors"
    else TestResult.pass),

  ("Contradictory effects: pure + IO", fun _ =>
    let func : Sage.Function := {
      name := "broken",
      params := [], returnType := Sage.SageType.name "String",
      requires := [], ensures := [], body := [],
      effects := [Sage.Effect.pure, Sage.Effect.io]
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then TestResult.pass
    else TestResult.fail "Pure + IO should produce error"),

  ("Duplicate effect warning", fun _ =>
    let func : Sage.Function := {
      name := "dup",
      params := [], returnType := Sage.SageType.name "String",
      requires := [], ensures := [], body := [],
      effects := [Sage.Effect.io, Sage.Effect.io]
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .warning) then TestResult.pass
    else TestResult.fail "Duplicate effects should produce warning")
]

-- 8.5 Termination verification tests
def terminationVerifyTests : List (String × (Unit → TestResult)) := [
  ("Recursive function without @decreases should error", fun _ =>
    -- A function that calls itself in its body
    let func : Sage.Function := {
      name := "loop",
      params := [],
      returnType := Sage.SageType.name "Unit",
      requires := [], ensures := [],
      body := [Sage.Stmt.expr (Sage.Expr.call "loop" [])]
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then TestResult.pass
    else TestResult.fail "Recursive function without @decreases should error"),

  ("Recursive function with valid @decreases", fun _ =>
    let func : Sage.Function := {
      name := "factorial",
      params := [("n", Sage.SageType.name "Nat")],
      returnType := Sage.SageType.name "Nat",
      requires := [], ensures := [],
      body := [Sage.Stmt.expr (Sage.Expr.call "factorial" [Sage.Expr.ident "n"])],
      decreases := some (Sage.Expr.ident "n")
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then
      TestResult.fail "Recursive function with valid @decreases should not error"
    else TestResult.pass),

  ("Non-recursive function with unnecessary @decreases", fun _ =>
    let func : Sage.Function := {
      name := "add",
      params := [], returnType := Sage.SageType.name "Int",
      requires := [], ensures := [], body := [],
      decreases := some (Sage.Expr.ident "n")
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .warning) then TestResult.pass
    else TestResult.fail "Non-recursive with @decreases should warn"),

  ("Recursive function with constant @decreases should error", fun _ =>
    let func : Sage.Function := {
      name := "loop",
      params := [],
      returnType := Sage.SageType.name "Unit",
      requires := [], ensures := [],
      body := [Sage.Stmt.expr (Sage.Expr.call "loop" [])],
      decreases := some (Sage.Expr.num 42.0)
    }
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [func], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    let result := Sage.verifyProgram prog
    if result.messages.any (fun m => m.severity == .error) then TestResult.pass
    else TestResult.fail "Constant @decreases should error")
]

-- All type checker tests
def allTypeCheckerTests : List (String × (Unit → TestResult)) :=
  basicTests ++ typeDeclarationTests ++ functionTests ++ integrationTests ++ edgeCaseTests ++ performanceTests ++
  refinementTypeVerifyTests ++ contractVerifyTests ++ invariantVerifyTests ++ effectVerifyTests ++ terminationVerifyTests

end SageTest.TypeChecker