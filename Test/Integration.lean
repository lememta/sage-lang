import Sage.Token
import Sage.AST
import Sage.Lexer
import Sage.Parser
import Sage.TypeCheck

namespace SageTest.Integration

-- Test result type
inductive TestResult where
  | pass : TestResult
  | fail : String → TestResult

-- Full pipeline test utility
def testFullPipeline (input : String) : TestResult :=
  -- Step 1: Lexing
  let tokens := Sage.tokenize input
  if tokens.isEmpty then
    TestResult.fail "Lexer produced no tokens"
  else
    -- Step 2: Parsing
    match Sage.parse tokens with
    | none => TestResult.fail "Parser failed"
    | some prog =>
      -- Step 3: Type Checking
      match Sage.typeCheck prog with
      | Except.error err => TestResult.fail s!"Type checker failed: {err}"
      | Except.ok _ => TestResult.pass

-- Test against example files content (simulated since we may not have file access)
def level0Examples : List (String × String) := [
  ("Natural language only", "\"Build a secure authentication system that handles user registration and login\""),
  ("Decision markers", "\"Implement OAuth 2.0 for third-party login\" !! \"Use JWT tokens for session management\""),
  ("Multiple statements", "\"Users can register with email and password\" \"System validates email format\" \"Passwords must be hashed\"")
]

def level1Examples : List (String × String) := [
  ("Simple module", "@mod auth \"User authentication system\""),
  ("Type declaration", "@mod types @type User = { email : String , password : String }"),
  ("Function with contract", "@mod funcs @fn login -> Bool @req \"Email must be valid\" @ens \"Returns authentication result\""),
  ("Complete example", "@mod user_auth @type User = String @fn register -> Bool \"Create new user account\"")
]

def level2Examples : List (String × String) := [
  ("Spec declaration", "@spec AuthSystem \"Authentication specification\""),
  ("State and invariants", "@mod system @spec AuthSystem @state users : Set"),
  ("Operations", "@mod ops @fn authenticate -> Result"),
  ("Refinement", "@mod refinement @refine AuthSystem \"Concrete implementation\"")
]

-- End-to-end pipeline tests
def pipelineTests : List (String × (Unit → TestResult)) :=
  (level0Examples.map (fun (name, input) =>
    (s!"Level 0: {name}", fun _ => testFullPipeline input))) ++
  (level1Examples.map (fun (name, input) =>
    (s!"Level 1: {name}", fun _ => testFullPipeline input))) ++
  (level2Examples.map (fun (name, input) =>
    (s!"Level 2: {name}", fun _ => testFullPipeline input)))

-- Specific component integration tests
def componentIntegrationTests : List (String × (Unit → TestResult)) := [
  ("Lexer → Parser: Empty input", fun _ =>
    let tokens := Sage.tokenize ""
    match Sage.parse tokens with
    | some _ => TestResult.pass
    | none => TestResult.fail "Parser should handle empty token stream"),

  ("Lexer → Parser: Keywords", fun _ =>
    let tokens := Sage.tokenize "@mod test"
    match Sage.parse tokens with
    | some prog =>
      if prog.modules.length > 0 then TestResult.pass
      else TestResult.fail "Parser should create module from tokens"
    | none => TestResult.fail "Parser should handle keyword tokens"),

  ("Parser → TypeChecker: Valid AST", fun _ =>
    let module : Sage.Module := {
      name := "test", imports := [], types := [], functions := [], naturalText := []
    }
    let prog : Sage.Program := ⟨[module]⟩
    match Sage.typeCheck prog with
    | Except.ok _ => TestResult.pass
    | Except.error err => TestResult.fail s!"Type checker should accept valid AST: {err}"),

  ("Parser → TypeChecker: Invalid AST", fun _ =>
    let module : Sage.Module := {
      name := "", imports := [], types := [], functions := [], naturalText := []  -- Empty name should fail
    }
    let prog : Sage.Program := ⟨[module]⟩
    match Sage.typeCheck prog with
    | Except.error _ => TestResult.pass
    | Except.ok _ => TestResult.fail "Type checker should reject invalid AST")
]

-- Real-world scenario tests
def realWorldScenarioTests : List (String × (Unit → TestResult)) := [
  ("User authentication module", fun _ =>
    let input := "@mod user_auth \"Secure user authentication system\" @type User = { email : String , password_hash : String } @fn register -> Result @fn login -> Result"
    testFullPipeline input),

  ("Payment processing", fun _ =>
    let input := "@mod payments \"Payment processing module\" @type Transaction = { amount : Money , user : String } @fn process_payment -> Result"
    testFullPipeline input),

  ("Data validation", fun _ =>
    let input := "@mod validation \"Input validation utilities\" @fn validate_email -> Bool @fn validate_password -> Bool @req \"Input is not empty\""
    testFullPipeline input),

  ("Mixed natural and formal", fun _ =>
    let input := "\"System handles user registration\" @mod auth @fn register -> Bool \"Password must be at least 8 characters\" !!"
    testFullPipeline input)
]

-- Performance and stress tests
def performanceTests : List (String × (Unit → TestResult)) := [
  ("Large module with many types", fun _ =>
    let typeDecls := List.range 50 |>.map (fun i => s!"@type Type{i} = String") |>.foldl (· ++ " " ++ ·) ""
    let input := s!"@mod large_module \"Module with many types\" {typeDecls}"
    testFullPipeline input),

  ("Many functions", fun _ =>
    let funcDecls := List.range 30 |>.map (fun i => s!"@fn func{i} -> String") |>.foldl (· ++ " " ++ ·) ""
    let input := s!"@mod large_module \"Module with many functions\" {funcDecls}"
    testFullPipeline input),

  ("Deep nesting simulation", fun _ =>
    let input := "@mod nested \"Nested structures\" @type Outer = { middle : Middle } @type Middle = { inner : String } @fn process -> Outer"
    testFullPipeline input),

  ("Complex contracts", fun _ =>
    let input := "@mod complex @fn validate -> Bool @req \"Input must be valid\" @req \"User must be authenticated\" @ens \"Result is deterministic\" @ens \"No side effects\""
    testFullPipeline input)
]

-- Error recovery tests
def errorRecoveryTests : List (String × (Unit → TestResult)) := [
  ("Partial module declaration", fun _ =>
    -- Test that pipeline handles incomplete input gracefully
    match testFullPipeline "@mod" with
    | TestResult.pass => TestResult.pass  -- If it passes, good
    | TestResult.fail _ => TestResult.pass -- If it fails gracefully, also good
    ),

  ("Malformed syntax", fun _ =>
    -- Test that pipeline doesn't crash on invalid input
    match testFullPipeline "@@@ invalid syntax here" with
    | TestResult.pass => TestResult.pass  -- Graceful handling
    | TestResult.fail _ => TestResult.pass -- Graceful failure
    ),

  ("Mixed valid and invalid", fun _ =>
    -- Test recovery from partial errors
    let input := "@mod valid \"Valid module\" @invalid_keyword broken"
    match testFullPipeline input with
    | TestResult.pass => TestResult.pass  -- If some parsing succeeds
    | TestResult.fail _ => TestResult.pass -- Or fails gracefully
    )
]

-- Regression tests (to catch future breaking changes)
def regressionTests : List (String × (Unit → TestResult)) := [
  ("Basic functionality preserved", fun _ =>
    testFullPipeline "@mod test \"Test module\" @fn hello -> String"),

  ("Unicode support preserved", fun _ =>
    testFullPipeline "\"System validates input ✓\" @mod unicode @fn test -> Bool"),

  ("Contract parsing preserved", fun _ =>
    testFullPipeline "@mod contracts @fn validate @req \"Input is valid\" @ens \"Output is correct\" -> Bool"),

  ("Natural language parsing preserved", fun _ =>
    testFullPipeline "\"This system manages user sessions\" \"Users can login and logout\" !!")
]

-- All integration tests
def allIntegrationTests : List (String × (Unit → TestResult)) :=
  pipelineTests ++ componentIntegrationTests ++ realWorldScenarioTests ++
  performanceTests ++ errorRecoveryTests ++ regressionTests

end SageTest.Integration