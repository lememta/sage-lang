import Sage.Token
import Sage.AST
import Sage.Lexer

namespace Sage

-- Skip tokens until we find a specific token type
partial def skipToToken (tokens : List Token) (target : TokenType) (acc : List (String × SageType)) : List (String × SageType) × List Token :=
  match tokens with
  | [] => (acc, [])
  | token :: rest =>
    if token.type == target then
      (acc, rest)
    else
      skipToToken rest target acc

-- Parse a single expression from a token (simplified)
def parseExprToken (token : Token) : Expr :=
  if token.type == TokenType.string then
    Expr.lit token.value
  else if token.type == TokenType.number then
    Expr.num (token.value.toNat?.getD 0 |>.toFloat)
  else if token.type == TokenType.true_ then
    Expr.bool true
  else if token.type == TokenType.false_ then
    Expr.bool false
  else
    Expr.ident token.value

-- Check if a token marks a boundary (end of an expression context)
def isBoundaryToken (t : TokenType) : Bool :=
  t == TokenType.mod || t == TokenType.fn || t == TokenType.type ||
  t == TokenType.eof || t == TokenType.req || t == TokenType.ens ||
  t == TokenType.effect || t == TokenType.decreases ||
  t == TokenType.pure_ || t == TokenType.total || t == TokenType.partial_ ||
  t == TokenType.invariant

-- Parse an expression that may include binary operators and logical quantifiers
-- Returns (expr, remaining tokens)
partial def parseExprTokens (tokens : List Token) : Expr × List Token :=
  match tokens with
  | [] => (Expr.ident "", [])
  | token :: rest =>
    -- 8.2/8.3: Quantifier expressions: ∀ x : T, P(x) / ∃ x : T, P(x)
    if token.type == TokenType.forall_ then
      parseQuantifier true rest
    else if token.type == TokenType.exists_ then
      parseQuantifier false rest
    else
      -- Simple expression: identifier, literal, or binary op
      let lhs := parseExprToken token
      parseBinOp lhs rest
where
  parseQuantifier (isForall : Bool) (tokens : List Token) : Expr × List Token :=
    match tokens with
    | varToken :: colonToken :: typeToken :: _commaToken :: bodyTokens =>
      if colonToken.type == TokenType.colon then
        let typeName := typeToken.value
        let (bodyExpr, remaining) := parseExprTokens bodyTokens
        let e := if isForall then Expr.forall_ varToken.value typeName bodyExpr
                 else Expr.exists_ varToken.value typeName bodyExpr
        (e, remaining)
      else
        -- Quantifier without type annotation
        let (bodyExpr, remaining) := parseExprTokens (colonToken :: typeToken :: _commaToken :: bodyTokens)
        let e := if isForall then Expr.forall_ varToken.value "Any" bodyExpr
                 else Expr.exists_ varToken.value "Any" bodyExpr
        (e, remaining)
    | varToken :: bodyTokens =>
      let (bodyExpr, remaining) := parseExprTokens bodyTokens
      let e := if isForall then Expr.forall_ varToken.value "Any" bodyExpr
               else Expr.exists_ varToken.value "Any" bodyExpr
      (e, remaining)
    | _ => (Expr.ident "", tokens)
  parseBinOp (lhs : Expr) (tokens : List Token) : Expr × List Token :=
    match tokens with
    | opToken :: rhs :: remaining =>
      -- ∈ (elementOf)
      if opToken.type == TokenType.elementOf then
        (Expr.elementOf lhs (parseExprToken rhs), remaining)
      -- ⟹ / => (implies)
      else if opToken.type == TokenType.fatArrow then
        let (rhsExpr, remaining') := parseExprTokens (rhs :: remaining)
        (Expr.implies lhs rhsExpr, remaining')
      -- Binary comparison/arithmetic/logical operators
      else if opToken.type == TokenType.gt || opToken.type == TokenType.lt ||
              opToken.type == TokenType.ge || opToken.type == TokenType.le ||
              opToken.type == TokenType.eq || opToken.type == TokenType.ne ||
              opToken.type == TokenType.plus || opToken.type == TokenType.minus ||
              opToken.type == TokenType.star || opToken.type == TokenType.slash ||
              opToken.type == TokenType.and || opToken.type == TokenType.or then
        (Expr.binOp opToken.value lhs (parseExprToken rhs), remaining)
      else
        (lhs, opToken :: rhs :: remaining)
    | _ => (lhs, tokens)

-- Parse an effect identifier into an Effect value
def parseEffectValue (name : String) : Option Effect :=
  match name with
  | "IO" | "io" => some Effect.io
  | "Mutation" | "mutation" => some Effect.mutation
  | "Exception" | "exception" => some Effect.exception
  | "Diverge" | "diverge" => some Effect.diverge
  | "Pure" | "pure" => some Effect.pure
  | _ => none

-- Parsed function body accumulator
structure ParsedBody where
  requires : List Expr := []
  ensures : List Expr := []
  effects : List Effect := []
  decreases : Option Expr := none
  body : List Stmt := []
  remaining : List Token := []

-- Parse function body: contracts (@req, @ens), effects (@effect), termination (@decreases), and statements
partial def parseFunctionBodyTokens (tokens : List Token) (result : ParsedBody) : ParsedBody :=
  match tokens with
  | [] => { result with remaining := [] }
  | token :: rest =>
    match token.type with
    -- 8.2 Pre/Post Conditions
    | TokenType.req =>
      match rest with
      | exprToken :: remaining =>
        if exprToken.type == TokenType.forall_ || exprToken.type == TokenType.exists_ then
          let (e, rem) := parseExprTokens (exprToken :: remaining)
          parseFunctionBodyTokens rem { result with requires := result.requires ++ [e] }
        else
          let expr := if exprToken.type == TokenType.string then Expr.lit exprToken.value
                      else Expr.ident exprToken.value
          parseFunctionBodyTokens remaining { result with requires := result.requires ++ [expr] }
      | [] => result

    | TokenType.ens =>
      match rest with
      | exprToken :: remaining =>
        if exprToken.type == TokenType.forall_ || exprToken.type == TokenType.exists_ then
          let (e, rem) := parseExprTokens (exprToken :: remaining)
          parseFunctionBodyTokens rem { result with ensures := result.ensures ++ [e] }
        else
          let expr := if exprToken.type == TokenType.string then Expr.lit exprToken.value
                      else Expr.ident exprToken.value
          parseFunctionBodyTokens remaining { result with ensures := result.ensures ++ [expr] }
      | [] => result

    -- 8.4 Effect Tracking: Parse @effect annotations
    | TokenType.effect =>
      match rest with
      | effectToken :: remaining =>
        match parseEffectValue effectToken.value with
        | some eff =>
          parseFunctionBodyTokens remaining { result with effects := result.effects ++ [eff] }
        | none =>
          -- Unknown effect name — skip
          parseFunctionBodyTokens remaining result
      | [] => result

    -- 8.4 Shorthand: @pure marks function as effect-free
    | TokenType.pure_ =>
      parseFunctionBodyTokens rest { result with effects := result.effects ++ [Effect.pure] }

    -- 8.5 Termination Proofs: Parse @decreases measure
    | TokenType.decreases =>
      match rest with
      | exprToken :: remaining =>
        if isBoundaryToken exprToken.type then
          -- No expression after @decreases, skip
          parseFunctionBodyTokens (exprToken :: remaining) result
        else
          let (expr, rem) := parseExprTokens (exprToken :: remaining)
          parseFunctionBodyTokens rem { result with decreases := some expr }
      | [] => result

    | TokenType.string =>
      -- Natural language statement
      let isImportant :=
        match rest with
        | importantToken :: _ => importantToken.type == TokenType.important
        | [] => false
      let stmt := Stmt.naturalText token.value isImportant
      let nextTokens := if isImportant then
        match rest with
        | _ :: remaining => remaining
        | [] => []
      else
        rest
      parseFunctionBodyTokens nextTokens { result with body := result.body ++ [stmt] }

    | TokenType.let =>
      -- Let statement (simplified)
      match rest with
      | nameToken :: assignToken :: exprToken :: remaining =>
        if nameToken.type == TokenType.identifier && assignToken.type == TokenType.assign then
          let expr := Expr.ident exprToken.value
          let stmt := Stmt.letBind nameToken.value none expr
          parseFunctionBodyTokens remaining { result with body := result.body ++ [stmt] }
        else
          parseFunctionBodyTokens rest result
      | _ => { result with remaining := rest }

    | TokenType.ret =>
      -- Return statement (simplified)
      match rest with
      | exprToken :: remaining =>
        let expr := Expr.ident exprToken.value
        let stmt := Stmt.ret expr
        parseFunctionBodyTokens remaining { result with body := result.body ++ [stmt] }
      | [] => result

    | TokenType.mod | TokenType.fn | TokenType.type | TokenType.eof =>
      -- End of function body
      { result with remaining := token :: rest }
    | _ =>
      -- Skip unrecognized tokens
      parseFunctionBodyTokens rest result

-- 8.1 Refinement Types: Collect tokens until matching '}'
private def collectTokensUntilBrace (tokens : List Token) (acc : List Token) : List Token × List Token :=
  match tokens with
  | [] => (acc, [])
  | token :: rest =>
    if token.type == TokenType.rbrace then (acc, rest)
    else collectTokensUntilBrace rest (acc ++ [token])

-- 8.1 Refinement Types: Convert collected tokens into an expression
private def tokensToExpr (tokens : List Token) : Expr :=
  match tokens with
  | [] => Expr.bool true
  | [single] => parseExprToken single
  | first :: op :: second :: _ =>
    if op.type == TokenType.gt || op.type == TokenType.lt ||
       op.type == TokenType.ge || op.type == TokenType.le ||
       op.type == TokenType.eq || op.type == TokenType.ne ||
       op.type == TokenType.and || op.type == TokenType.or ||
       op.type == TokenType.plus || op.type == TokenType.minus then
      Expr.binOp op.value (parseExprToken first) (parseExprToken second)
    else
      parseExprToken first
  | first :: _ => parseExprToken first

-- 8.1 Refinement Types: Parse { x : T | P(x) }
-- Called after seeing '{' in a type context
def parseRefinementType (tokens : List Token) : Option (SageType × List Token) :=
  match tokens with
  | varToken :: colonToken :: typeToken :: pipeToken :: rest =>
    if colonToken.type == TokenType.colon && pipeToken.type == TokenType.pipe then
      let varName := varToken.value
      let baseType := SageType.name typeToken.value
      -- Collect predicate tokens until '}'
      let (predTokens, remaining) := collectTokensUntilBrace rest []
      let predExpr := tokensToExpr predTokens
      some (SageType.refined varName baseType predExpr, remaining)
    else
      none
  | _ => none

-- 8.3 Data Structure Invariants: Parse @invariant annotations after type declarations
private partial def parseTypeInvariants (tokens : List Token) (acc : List Expr) : List Expr × List Token :=
  match tokens with
  | token :: rest =>
    if token.type == TokenType.invariant then
      match rest with
      | exprToken :: remaining =>
        if isBoundaryToken exprToken.type then
          (acc, tokens)
        else
          let (expr, rem) := parseExprTokens (exprToken :: remaining)
          parseTypeInvariants rem (acc ++ [expr])
      | [] => (acc, [])
    else
      (acc, tokens)
  | [] => (acc, [])

-- Parse type declaration from tokens
def parseTypeTokens (tokens : List Token) : Option (TypeDecl × List Token) :=
  match tokens with
  | nameToken :: assignToken :: rest =>
    if (nameToken.type == TokenType.identifier || nameToken.type == TokenType.typeName) &&
       assignToken.type == TokenType.assign then
      let typeName := nameToken.value
      -- Check for refinement type, struct, or simple name
      match rest with
      | typeToken :: remaining =>
        if typeToken.type == TokenType.lbrace then
          -- Try refinement type: { x : T | P(x) }
          match parseRefinementType remaining with
          | some (refinedType, afterRefined) =>
            let (invariants, finalRemaining) := parseTypeInvariants afterRefined []
            some ({ name := typeName, definition := refinedType, invariants := invariants }, finalRemaining)
          | none =>
            -- Fallback: regular struct type
            let (invariants, finalRemaining) := parseTypeInvariants remaining []
            some ({ name := typeName, definition := SageType.struct [], invariants := invariants }, finalRemaining)
        else
          let typeDefinition := SageType.name typeToken.value
          let (invariants, finalRemaining) := parseTypeInvariants remaining []
          some ({ name := typeName, definition := typeDefinition, invariants := invariants }, finalRemaining)
      | [] => none
    else
      none
  | _ => none

-- Parse function declaration from tokens
def parseFunctionTokens (tokens : List Token) : Option (Function × List Token) :=
  match tokens with
  | nameToken :: rest =>
    if nameToken.type == TokenType.identifier then
      let funcName := nameToken.value

      -- Parse parameters (simplified - just skip parentheses)
      let (params, tokens1) :=
        match rest with
        | lparen :: remaining =>
          if lparen.type == TokenType.lparen then
            skipToToken remaining TokenType.rparen []
          else
            ([], rest)
        | _ => ([], rest)

      -- Parse return type (simplified - look for ->)
      let (returnType, tokens2) :=
        match tokens1 with
        | arrow :: typeToken :: remaining =>
          if arrow.type == TokenType.arrow then
            (SageType.name typeToken.value, remaining)
          else
            (SageType.name "Unit", tokens1)
        | _ => (SageType.name "Unit", tokens1)

      -- Parse optional description
      let (_description, tokens3) :=
        match tokens2 with
        | descToken :: remaining =>
          if descToken.type == TokenType.string then
            (descToken.value, remaining)
          else
            ("", tokens2)
        | _ => ("", tokens2)

      -- Parse contracts, effects, termination measure, and body
      let parsed := parseFunctionBodyTokens tokens3 {}

      let func : Function := {
        name := funcName,
        params := params,
        returnType := returnType,
        requires := parsed.requires,
        ensures := parsed.ensures,
        effects := parsed.effects,
        decreases := parsed.decreases,
        body := parsed.body
      }
      some (func, parsed.remaining)
    else
      none
  | [] => none

-- Parse module body from tokens
partial def parseModuleBodyTokens (tokens : List Token) (types : List TypeDecl) (functions : List Function) (naturalText : List String) : List TypeDecl × List Function × List String × List Token :=
  match tokens with
  | [] => (types, functions, naturalText, [])
  | token :: rest =>
    match token.type with
    | TokenType.type =>
      -- Parse type declaration
      match parseTypeTokens rest with
      | some (typeDecl, remainingTokens) =>
        parseModuleBodyTokens remainingTokens (types ++ [typeDecl]) functions naturalText
      | none =>
        parseModuleBodyTokens rest types functions naturalText
    | TokenType.fn =>
      -- Parse function declaration
      match parseFunctionTokens rest with
      | some (func, remainingTokens) =>
        parseModuleBodyTokens remainingTokens types (functions ++ [func]) naturalText
      | none =>
        parseModuleBodyTokens rest types functions naturalText
    | TokenType.string =>
      -- Natural language text
      parseModuleBodyTokens rest types functions (naturalText ++ [token.value])
    | TokenType.mod | TokenType.eof =>
      -- End of module or file
      (types, functions, naturalText, token :: rest)
    | _ =>
      -- Skip other tokens
      parseModuleBodyTokens rest types functions naturalText

-- Parse module from tokens
def parseModuleTokens (tokens : List Token) : Option (Module × List Token) :=
  match tokens with
  | nameToken :: rest =>
    if nameToken.type == TokenType.identifier then
      let moduleName := nameToken.value
      let (description, tokens') :=
        match rest with
        | descToken :: rest' =>
          if descToken.type == TokenType.string then
            (descToken.value, rest')
          else
            ("", rest)
        | [] => ("", [])

      -- Parse module body
      let (types, functions, naturalText, remainingTokens) := parseModuleBodyTokens tokens' [] [] []

      let module : Module := {
        name := moduleName,
        imports := [],
        types := types,
        functions := functions,
        naturalText := if description.length > 0 then [description] ++ naturalText else naturalText
      }
      some (module, remainingTokens)
    else
      none
  | [] => none

-- Parse tokens into modules
partial def parseTokensToModules (tokens : List Token) (acc : List Module) : List Module :=
  match tokens with
  | [] => acc
  | token :: rest =>
    match token.type with
    | TokenType.mod =>
      -- Parse module
      match parseModuleTokens rest with
      | some (module, remainingTokens) =>
        parseTokensToModules remainingTokens (acc ++ [module])
      | none => parseTokensToModules rest acc
    | TokenType.string =>
      -- Standalone natural language - create default module
      let module : Module := {
        name := "default",
        imports := [],
        types := [],
        functions := [],
        naturalText := [token.value]
      }
      parseTokensToModules rest (acc ++ [module])
    | _ => parseTokensToModules rest acc

-- Simple parser that builds basic AST structures
def parse (tokens : List Token) : Option Program :=
  let modules := parseTokensToModules tokens []
  some ⟨modules⟩

end Sage
