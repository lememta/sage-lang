import Sage.Token
import Sage.AST
import Sage.Lexer
import Sage.Parser
import Sage.TypeCheck
import Sage.Verify

namespace SageTest

-- Test result type
inductive TestResult where
  | pass : TestResult
  | fail : String → TestResult

-- Test case structure
structure TestCase where
  name : String
  test : Unit → TestResult

-- Test assertion utilities
def assert (condition : Bool) (message : String) : TestResult :=
  if condition then TestResult.pass else TestResult.fail message

def assertEqual (a b : α) [BEq α] [Repr α] (message : String := "Assertion failed") : TestResult :=
  if a == b then
    TestResult.pass
  else
    TestResult.fail s!"{message}: expected {repr b}, got {repr a}"

def assertSome (opt : Option α) (message : String := "Expected Some, got None") : TestResult :=
  match opt with
  | some _ => TestResult.pass
  | none => TestResult.fail message

def assertNone (opt : Option α) (message : String := "Expected None, got Some") : TestResult :=
  match opt with
  | none => TestResult.pass
  | some _ => TestResult.fail message

-- Test runner
def runTest (test : TestCase) : IO Bool := do
  IO.println s!"Running test: {test.name}"
  match test.test () with
  | TestResult.pass =>
    IO.println "  ✓ PASS"
    pure true
  | TestResult.fail message =>
    IO.println s!"  ✗ FAIL: {message}"
    pure false

def runTests (tests : List TestCase) : IO Nat :=
  let runSingle := fun (acc : IO Nat) (test : TestCase) => do
    let failuresSoFar ← acc
    let passed ← runTest test
    pure (if passed then failuresSoFar else failuresSoFar + 1)

  tests.foldl runSingle (pure 0)

-- Sample test cases to verify the framework works
def sampleTests : List TestCase := [
  { name := "Basic arithmetic",
    test := fun _ => assertEqual (2 + 2) 4 "Basic addition should work" },
  { name := "String equality",
    test := fun _ => assertEqual "hello" "hello" "String equality should work" },
  { name := "Option Some test",
    test := fun _ => assertSome (some 42) "Should recognize Some value" }
]

-- Basic lexer tests
def lexerTests : List TestCase := [
  { name := "Lexer: EOF token for empty input",
    test := fun _ =>
      let tokens := Sage.tokenize ""
      match tokens with
      | [token] => if token.type == Sage.TokenType.eof then TestResult.pass
                   else TestResult.fail "Expected EOF token"
      | _ => TestResult.fail "Expected single EOF token" },

  { name := "Lexer: @mod keyword",
    test := fun _ =>
      let tokens := Sage.tokenize "@mod test_module"
      match tokens with
      | modToken :: nameToken :: eofToken :: [] =>
        if modToken.type == Sage.TokenType.mod &&
           nameToken.type == Sage.TokenType.identifier &&
           eofToken.type == Sage.TokenType.eof then
          TestResult.pass
        else
          TestResult.fail "Expected @mod, identifier, EOF tokens"
      | _ => TestResult.fail "Unexpected token sequence" },

  { name := "Lexer: String literal",
    test := fun _ =>
      let tokens := Sage.tokenize "\"Hello World\""
      match tokens with
      | stringToken :: eofToken :: [] =>
        if stringToken.type == Sage.TokenType.string && stringToken.value == "\"Hello World\"" then
          TestResult.pass
        else
          TestResult.fail s!"Expected string token with 'Hello World', got {stringToken.value}"
      | _ => TestResult.fail "Expected string token and EOF" },

  { name := "Lexer: Important marker",
    test := fun _ =>
      let tokens := Sage.tokenize "!!"
      match tokens with
      | importantToken :: eofToken :: [] =>
        if importantToken.type == Sage.TokenType.important then
          TestResult.pass
        else
          TestResult.fail "Expected important (!!) token"
      | _ => TestResult.fail "Expected important token and EOF" }
]

-- Basic parser tests
def parserTests : List TestCase := [
  { name := "Parser: Empty input",
    test := fun _ =>
      let tokens := Sage.tokenize ""
      match Sage.parse tokens with
      | some prog => TestResult.pass
      | none => TestResult.fail "Parser should handle empty input" },

  { name := "Parser: Simple module",
    test := fun _ =>
      let tokens := Sage.tokenize "@mod test_module \"A test module\""
      match Sage.parse tokens with
      | some prog =>
        if prog.modules.length > 0 then TestResult.pass
        else TestResult.fail "Expected at least one module"
      | none => TestResult.fail "Parser should handle simple module" },

  { name := "Parser: Natural language",
    test := fun _ =>
      let tokens := Sage.tokenize "\"This is natural language\""
      match Sage.parse tokens with
      | some prog =>
        if prog.modules.length > 0 then TestResult.pass
        else TestResult.fail "Expected module with natural language"
      | none => TestResult.fail "Parser should handle natural language" }
]

-- Basic type checker tests
def typeCheckerTests : List TestCase := [
  { name := "TypeChecker: Empty program",
    test := fun _ =>
      let prog : Sage.Program := ⟨[]⟩
      match Sage.typeCheck prog with
      | Except.ok _ => TestResult.pass
      | Except.error err => TestResult.fail s!"Type checking failed: {err}" },

  { name := "TypeChecker: Simple valid module",
    test := fun _ =>
      let module : Sage.Module := {
        name := "test",
        imports := [],
        types := [],
        functions := [],
        naturalText := ["Test module"]
      }
      let prog : Sage.Program := ⟨[module]⟩
      match Sage.typeCheck prog with
      | Except.ok _ => TestResult.pass
      | Except.error err => TestResult.fail s!"Type checking failed: {err}" }
]

-- Integration tests (end-to-end)
def integrationTests : List TestCase := [
  { name := "Integration: Lex → Parse → TypeCheck empty",
    test := fun _ =>
      let tokens := Sage.tokenize ""
      match Sage.parse tokens with
      | some prog =>
        match Sage.typeCheck prog with
        | Except.ok _ => TestResult.pass
        | Except.error err => TestResult.fail s!"Type checking failed: {err}"
      | none => TestResult.fail "Parsing failed" },

  { name := "Integration: Lex → Parse → TypeCheck simple module",
    test := fun _ =>
      let tokens := Sage.tokenize "@mod test \"A simple test module\""
      match Sage.parse tokens with
      | some prog =>
        match Sage.typeCheck prog with
        | Except.ok _ => TestResult.pass
        | Except.error err => TestResult.fail s!"Type checking failed: {err}"
      | none => TestResult.fail "Parsing failed" }
]

-- Verification engine tests
def verificationTests : List TestCase := [
  { name := "Verify: empty program",
    test := fun _ =>
      let prog : Sage.Program := ⟨[]⟩
      let result := Sage.verifyProgram prog
      if result.hasErrors then TestResult.fail "Empty program should verify"
      else TestResult.pass },

  { name := "Verify: pure function is valid",
    test := fun _ =>
      let func : Sage.Function := {
        name := "add", params := [], returnType := Sage.SageType.name "Int",
        requires := [], ensures := [], body := [], effects := [Sage.Effect.pure]
      }
      let module : Sage.Module := {
        name := "math", imports := [], types := [], functions := [func], naturalText := []
      }
      let result := Sage.verifyProgram ⟨[module]⟩
      if result.hasErrors then TestResult.fail "Pure function should verify"
      else TestResult.pass },

  { name := "Verify: contradictory effects detected",
    test := fun _ =>
      let func : Sage.Function := {
        name := "bad", params := [], returnType := Sage.SageType.name "String",
        requires := [], ensures := [], body := [],
        effects := [Sage.Effect.pure, Sage.Effect.io]
      }
      let module : Sage.Module := {
        name := "test", imports := [], types := [], functions := [func], naturalText := []
      }
      let result := Sage.verifyProgram ⟨[module]⟩
      if result.hasErrors then TestResult.pass
      else TestResult.fail "Pure + IO should be detected as error" },

  { name := "Verify: recursive function needs @decreases",
    test := fun _ =>
      let func : Sage.Function := {
        name := "loop", params := [], returnType := Sage.SageType.name "Unit",
        requires := [], ensures := [],
        body := [Sage.Stmt.expr (Sage.Expr.call "loop" [])]
      }
      let module : Sage.Module := {
        name := "test", imports := [], types := [], functions := [func], naturalText := []
      }
      let result := Sage.verifyProgram ⟨[module]⟩
      if result.hasErrors then TestResult.pass
      else TestResult.fail "Recursive without @decreases should error" },

  { name := "Verify: refinement type with false predicate",
    test := fun _ =>
      let typeDecl : Sage.TypeDecl := {
        name := "Empty",
        definition := Sage.SageType.refined "x" (Sage.SageType.name "Int") (Sage.Expr.bool false)
      }
      let module : Sage.Module := {
        name := "test", imports := [], types := [typeDecl], functions := [], naturalText := []
      }
      let result := Sage.verifyProgram ⟨[module]⟩
      if result.hasErrors then TestResult.pass
      else TestResult.fail "False refinement predicate should error" }
]

-- All tests combined
def allTests : List TestCase :=
  sampleTests ++ lexerTests ++ parserTests ++ typeCheckerTests ++ integrationTests ++ verificationTests

end SageTest

-- Main test runner function (outside namespace)
def main (args : List String) : IO UInt32 := do
  IO.println "=== SAGE Language Test Suite ==="
  IO.println ""

  IO.println "Running Sample Tests..."
  let sampleFailures ← SageTest.runTests SageTest.sampleTests

  IO.println "\nRunning Lexer Tests..."
  let lexerFailures ← SageTest.runTests SageTest.lexerTests

  IO.println "\nRunning Parser Tests..."
  let parserFailures ← SageTest.runTests SageTest.parserTests

  IO.println "\nRunning Type Checker Tests..."
  let typeCheckerFailures ← SageTest.runTests SageTest.typeCheckerTests

  IO.println "\nRunning Integration Tests..."
  let integrationFailures ← SageTest.runTests SageTest.integrationTests

  IO.println "\nRunning Verification Tests..."
  let verificationFailures ← SageTest.runTests SageTest.verificationTests

  let totalFailures := sampleFailures + lexerFailures + parserFailures + typeCheckerFailures + integrationFailures + verificationFailures
  let totalTests := SageTest.allTests.length
  let passedTests := totalTests - totalFailures

  IO.println ""
  IO.println "=== Test Results ==="
  IO.println s!"Total tests: {totalTests}"
  IO.println s!"Passed: {passedTests}"
  IO.println s!"Failed: {totalFailures}"

  if totalFailures == 0 then
    IO.println "🎉 All tests passed!"
    pure 0
  else
    IO.println s!"❌ {totalFailures} test(s) failed"
    pure 1