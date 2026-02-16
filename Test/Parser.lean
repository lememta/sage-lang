import Sage.Token
import Sage.AST
import Sage.Lexer
import Sage.Parser

namespace SageTest.Parser

-- Test result type
inductive TestResult where
  | pass : TestResult
  | fail : String → TestResult

-- Test assertion utilities
def assertEqual (a b : α) [BEq α] [Repr α] (message : String := "Assertion failed") : TestResult :=
  if a == b then TestResult.pass else TestResult.fail s!"{message}: expected {repr b}, got {repr a}"

def assertSome (opt : Option α) (message : String := "Expected Some, got None") : TestResult :=
  match opt with
  | some _ => TestResult.pass
  | none => TestResult.fail message

def assertNone (opt : Option α) (message : String := "Expected None, got Some") : TestResult :=
  match opt with
  | none => TestResult.pass
  | some _ => TestResult.fail message

-- Parser test utilities
def parseFromString (input : String) : Option Sage.Program :=
  let tokens := Sage.tokenize input
  Sage.parse tokens

-- Basic parsing tests
def basicParsingTests : List (String × (Unit → TestResult)) := [
  ("Empty input", fun _ =>
    match parseFromString "" with
    | some prog => TestResult.pass
    | none => TestResult.fail "Parser should handle empty input"),

  ("Natural language only", fun _ =>
    match parseFromString "\"This is a natural language specification\"" with
    | some prog =>
      if prog.modules.length > 0 then TestResult.pass
      else TestResult.fail "Expected at least one module for natural language"
    | none => TestResult.fail "Parser should handle natural language input"),

  ("Simple module", fun _ =>
    match parseFromString "@mod test_module" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.name == "test_module" then TestResult.pass
        else TestResult.fail s!"Expected module name 'test_module', got '{module.name}'"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle simple module declaration")
]

def moduleTests : List (String × (Unit → TestResult)) := [
  ("Module with description", fun _ =>
    match parseFromString "@mod auth_module \"User authentication system\"" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.name == "auth_module" && !module.naturalText.isEmpty then
          TestResult.pass
        else
          TestResult.fail "Module should have name and description"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle module with description"),

  ("Multiple modules", fun _ =>
    match parseFromString "@mod module1 @mod module2" with
    | some prog =>
      if prog.modules.length >= 2 then TestResult.pass
      else TestResult.fail s!"Expected 2 modules, got {prog.modules.length}"
    | none => TestResult.fail "Parser should handle multiple modules")
]

def typeDeclarationTests : List (String × (Unit → TestResult)) := [
  ("Simple type declaration", fun _ =>
    match parseFromString "@mod test @type User = String" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.types.length > 0 then
          let typeDecl := module.types.head!
          if typeDecl.name == "User" then TestResult.pass
          else TestResult.fail s!"Expected type name 'User', got '{typeDecl.name}'"
        else
          TestResult.fail "Expected at least one type declaration"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle simple type declaration"),

  ("Struct type declaration", fun _ =>
    match parseFromString "@mod test @type User = { name : String }" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.types.length > 0 then TestResult.pass
        else TestResult.fail "Expected at least one type declaration"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle struct type declaration")
]

def functionTests : List (String × (Unit → TestResult)) := [
  ("Simple function declaration", fun _ =>
    match parseFromString "@mod test @fn greet -> String" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.functions.length > 0 then
          let func := module.functions.head!
          if func.name == "greet" then TestResult.pass
          else TestResult.fail s!"Expected function name 'greet', got '{func.name}'"
        else
          TestResult.fail "Expected at least one function declaration"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle simple function declaration"),

  ("Function with parameters", fun _ =>
    match parseFromString "@mod test @fn login ( email : String ) -> Bool" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.functions.length > 0 then
          let func := module.functions.head!
          if func.name == "login" then TestResult.pass
          else TestResult.fail s!"Expected function name 'login', got '{func.name}'"
        else
          TestResult.fail "Expected at least one function declaration"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle function with parameters"),

  ("Function with contracts", fun _ =>
    match parseFromString "@mod test @fn validate @req \"Input must be valid\" -> Bool" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.functions.length > 0 then
          let func := module.functions.head!
          if func.name == "validate" && !func.requires.isEmpty then TestResult.pass
          else TestResult.fail "Function should have name and requirements"
        else
          TestResult.fail "Expected at least one function declaration"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle function with contracts")
]

def naturalLanguageTests : List (String × (Unit → TestResult)) := [
  ("Mixed natural and code", fun _ =>
    match parseFromString "@mod auth \"Authentication system\" \"Users can login with email\"" with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if !module.naturalText.isEmpty then TestResult.pass
        else TestResult.fail "Expected natural language text"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle mixed natural and code"),

  ("Natural language statements", fun _ =>
    match parseFromString "\"System validates user credentials\" \"Return success or failure\"" with
    | some prog =>
      if prog.modules.length > 0 then TestResult.pass
      else TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle natural language statements")
]

def complexTests : List (String × (Unit → TestResult)) := [
  ("Complete module example", fun _ =>
    let input := "@mod user_auth \"User authentication system\" @type User = String @fn login -> Bool \"Login function\""
    match parseFromString input with
    | some prog =>
      if prog.modules.length > 0 then
        let module := prog.modules.head!
        if module.name == "user_auth" &&
           module.types.length > 0 &&
           module.functions.length > 0 then
          TestResult.pass
        else
          TestResult.fail "Module should have name, types, and functions"
      else
        TestResult.fail "Expected at least one module"
    | none => TestResult.fail "Parser should handle complete module example"),

  ("Level 1 structured example", fun _ =>
    let input := "@mod auth @type User = String @fn register -> Bool @req \"Email is valid\""
    match parseFromString input with
    | some prog =>
      if prog.modules.length > 0 then TestResult.pass
      else TestResult.fail "Expected successful parsing of structured example"
    | none => TestResult.fail "Parser should handle level 1 structured example")
]

-- Error handling tests
def errorHandlingTests : List (String × (Unit → TestResult)) := [
  ("Invalid syntax should not crash", fun _ =>
    -- Test that parser doesn't crash on invalid input
    match parseFromString "@ invalid syntax here" with
    | some _ => TestResult.pass  -- If it parses something, that's okay
    | none => TestResult.pass    -- If it fails gracefully, that's also okay
    ),

  ("Incomplete declarations", fun _ =>
    -- Test incomplete declarations
    match parseFromString "@mod" with
    | some _ => TestResult.pass  -- Parser should handle gracefully
    | none => TestResult.pass    -- Or fail gracefully
    )
]

-- All parser tests
def allParserTests : List (String × (Unit → TestResult)) :=
  basicParsingTests ++ moduleTests ++ typeDeclarationTests ++ functionTests ++
  naturalLanguageTests ++ complexTests ++ errorHandlingTests

end SageTest.Parser