import Sage.Token
import Sage.AST
import Sage.Lexer
import Sage.Parser
import Sage.TypeCheck

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

-- All type checker tests
def allTypeCheckerTests : List (String × (Unit → TestResult)) :=
  basicTests ++ typeDeclarationTests ++ functionTests ++ integrationTests ++ edgeCaseTests ++ performanceTests

end SageTest.TypeChecker