import Sage.Token
import Sage.Lexer

namespace SageTest.Lexer

-- Test result type
inductive TestResult where
  | pass : TestResult
  | fail : String → TestResult

-- Test assertion utilities
def assertEqual (a b : α) [BEq α] [Repr α] (message : String := "Assertion failed") : TestResult :=
  if a == b then TestResult.pass else TestResult.fail s!"{message}: expected {repr b}, got {repr a}"

def assertTokenType (token : Sage.Token) (expectedType : Sage.TokenType) : TestResult :=
  if token.type == expectedType then TestResult.pass
  else TestResult.fail s!"Expected token type {expectedType}, got {token.type}"

def assertTokenValue (token : Sage.Token) (expectedValue : String) : TestResult :=
  if token.value == expectedValue then TestResult.pass
  else TestResult.fail s!"Expected token value '{expectedValue}', got '{token.value}'"

-- Comprehensive lexer tests
def keywordTests : List (String × (Unit → TestResult)) := [
  ("@mod keyword", fun _ =>
    let tokens := Sage.tokenize "@mod"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.mod
    | none => TestResult.fail "No tokens produced"),

  ("@type keyword", fun _ =>
    let tokens := Sage.tokenize "@type"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.type
    | none => TestResult.fail "No tokens produced"),

  ("@fn keyword", fun _ =>
    let tokens := Sage.tokenize "@fn"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.fn
    | none => TestResult.fail "No tokens produced"),

  ("@spec keyword", fun _ =>
    let tokens := Sage.tokenize "@spec"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.spec
    | none => TestResult.fail "No tokens produced"),

  ("@req keyword", fun _ =>
    let tokens := Sage.tokenize "@req"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.req
    | none => TestResult.fail "No tokens produced"),

  ("@ens keyword", fun _ =>
    let tokens := Sage.tokenize "@ens"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.ens
    | none => TestResult.fail "No tokens produced")
]

def operatorTests : List (String × (Unit → TestResult)) := [
  ("Arrow operator", fun _ =>
    let tokens := Sage.tokenize "->"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.arrow
    | none => TestResult.fail "No tokens produced"),

  ("Fat arrow operator", fun _ =>
    let tokens := Sage.tokenize "=>"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.fatArrow
    | none => TestResult.fail "No tokens produced"),

  ("Important marker", fun _ =>
    let tokens := Sage.tokenize "!!"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.important
    | none => TestResult.fail "No tokens produced"),

  ("Equal operator", fun _ =>
    let tokens := Sage.tokenize "=="
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.eq
    | none => TestResult.fail "No tokens produced"),

  ("Not equal operator", fun _ =>
    let tokens := Sage.tokenize "!="
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.ne
    | none => TestResult.fail "No tokens produced"),

  ("And operator", fun _ =>
    let tokens := Sage.tokenize "&&"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.and
    | none => TestResult.fail "No tokens produced"),

  ("Or operator", fun _ =>
    let tokens := Sage.tokenize "||"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.or
    | none => TestResult.fail "No tokens produced")
]

def punctuationTests : List (String × (Unit → TestResult)) := [
  ("Left parenthesis", fun _ =>
    let tokens := Sage.tokenize "("
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.lparen
    | none => TestResult.fail "No tokens produced"),

  ("Right parenthesis", fun _ =>
    let tokens := Sage.tokenize ")"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.rparen
    | none => TestResult.fail "No tokens produced"),

  ("Left brace", fun _ =>
    let tokens := Sage.tokenize "{"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.lbrace
    | none => TestResult.fail "No tokens produced"),

  ("Right brace", fun _ =>
    let tokens := Sage.tokenize "}"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.rbrace
    | none => TestResult.fail "No tokens produced"),

  ("Comma", fun _ =>
    let tokens := Sage.tokenize ","
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.comma
    | none => TestResult.fail "No tokens produced"),

  ("Colon", fun _ =>
    let tokens := Sage.tokenize ":"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.colon
    | none => TestResult.fail "No tokens produced")
]

def literalTests : List (String × (Unit → TestResult)) := [
  ("String literal", fun _ =>
    let tokens := Sage.tokenize "\"Hello World\""
    match tokens.head? with
    | some token =>
      let typeCheck := assertTokenType token Sage.TokenType.string
      match typeCheck with
      | TestResult.pass => assertTokenValue token "\"Hello World\""
      | fail => fail
    | none => TestResult.fail "No tokens produced"),

  ("Identifier", fun _ =>
    let tokens := Sage.tokenize "myVariable"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.identifier
    | none => TestResult.fail "No tokens produced"),

  ("Type name", fun _ =>
    let tokens := Sage.tokenize "MyType"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.typeName
    | none => TestResult.fail "No tokens produced")
]

def unicodeTests : List (String × (Unit → TestResult)) := [
  ("Checkmark symbol", fun _ =>
    let tokens := Sage.tokenize "✓"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.checkmark
    | none => TestResult.fail "No tokens produced"),

  ("Cross mark symbol", fun _ =>
    let tokens := Sage.tokenize "✗"
    match tokens.head? with
    | some token => assertTokenType token Sage.TokenType.crossmark
    | none => TestResult.fail "No tokens produced")
]

def complexTests : List (String × (Unit → TestResult)) := [
  ("Module declaration", fun _ =>
    let tokens := Sage.tokenize "@mod user_auth \"User authentication module\""
    if tokens.length >= 3 then
      let modToken := tokens[0]!
      let nameToken := tokens[1]!
      let stringToken := tokens[2]!

      let check1 := assertTokenType modToken Sage.TokenType.mod
      match check1 with
      | TestResult.pass =>
        let check2 := assertTokenType nameToken Sage.TokenType.identifier
        match check2 with
        | TestResult.pass => assertTokenType stringToken Sage.TokenType.string
        | fail => fail
      | fail => fail
    else
      TestResult.fail s!"Expected at least 3 tokens, got {tokens.length}"),

  ("Function signature", fun _ =>
    let tokens := Sage.tokenize "@fn login ( email : Str ) -> Bool"
    -- Just check we get some reasonable number of tokens
    if tokens.length >= 8 then TestResult.pass
    else TestResult.fail s!"Expected at least 8 tokens for function signature, got {tokens.length}")
]

-- All lexer tests
def allLexerTests : List (String × (Unit → TestResult)) :=
  keywordTests ++ operatorTests ++ punctuationTests ++ literalTests ++ unicodeTests ++ complexTests

end SageTest.Lexer