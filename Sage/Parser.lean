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

-- Parse function body (contracts and statements)
partial def parseFunctionBodyTokens (tokens : List Token) (requires : List Expr) (ensures : List Expr) (body : List Stmt) : List Expr × List Expr × List Stmt × List Token :=
  match tokens with
  | [] => (requires, ensures, body, [])
  | token :: rest =>
    match token.type with
    | TokenType.req =>
      -- Parse requirement (simplified - just take next string as literal)
      match rest with
      | exprToken :: remaining =>
        let expr := if exprToken.type == TokenType.string then
          Expr.lit exprToken.value
        else
          Expr.ident exprToken.value
        parseFunctionBodyTokens remaining (requires ++ [expr]) ensures body
      | [] => (requires, ensures, body, [])
    | TokenType.ens =>
      -- Parse ensures (simplified - just take next string as literal)
      match rest with
      | exprToken :: remaining =>
        let expr := if exprToken.type == TokenType.string then
          Expr.lit exprToken.value
        else
          Expr.ident exprToken.value
        parseFunctionBodyTokens remaining requires (ensures ++ [expr]) body
      | [] => (requires, ensures, body, [])
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
      parseFunctionBodyTokens nextTokens requires ensures (body ++ [stmt])
    | TokenType.let =>
      -- Let statement (simplified)
      match rest with
      | nameToken :: assignToken :: exprToken :: remaining =>
        if nameToken.type == TokenType.identifier && assignToken.type == TokenType.assign then
          let expr := Expr.ident exprToken.value
          let stmt := Stmt.letBind nameToken.value none expr
          parseFunctionBodyTokens remaining requires ensures (body ++ [stmt])
        else
          parseFunctionBodyTokens rest requires ensures body
      | _ => (requires, ensures, body, rest)
    | TokenType.ret =>
      -- Return statement (simplified)
      match rest with
      | exprToken :: remaining =>
        let expr := Expr.ident exprToken.value
        let stmt := Stmt.ret expr
        parseFunctionBodyTokens remaining requires ensures (body ++ [stmt])
      | [] => (requires, ensures, body, [])
    | TokenType.mod | TokenType.fn | TokenType.eof =>
      -- End of function
      (requires, ensures, body, token :: rest)
    | _ =>
      -- Skip other tokens
      parseFunctionBodyTokens rest requires ensures body

-- Parse type declaration from tokens
def parseTypeTokens (tokens : List Token) : Option (TypeDecl × List Token) :=
  match tokens with
  | nameToken :: assignToken :: rest =>
    if (nameToken.type == TokenType.identifier || nameToken.type == TokenType.typeName) &&
       assignToken.type == TokenType.assign then
      let typeName := nameToken.value
      -- Simple type parsing - just take the next identifier as the type
      match rest with
      | typeToken :: remaining =>
        let typeDefinition :=
          if typeToken.type == TokenType.lbrace then
            -- Struct type - for now just create a simple struct
            SageType.struct []
          else
            SageType.name typeToken.value
        let typeDecl : TypeDecl := {
          name := typeName,
          definition := typeDefinition
        }
        some (typeDecl, remaining)
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
      let (description, tokens3) :=
        match tokens2 with
        | descToken :: remaining =>
          if descToken.type == TokenType.string then
            (descToken.value, remaining)
          else
            ("", tokens2)
        | _ => ("", tokens2)

      -- Parse contracts and body (simplified)
      let (requires, ensures, body, remainingTokens) := parseFunctionBodyTokens tokens3 [] [] []

      let func : Function := {
        name := funcName,
        params := params,
        returnType := returnType,
        requires := requires,
        ensures := ensures,
        body := body
      }
      some (func, remainingTokens)
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
