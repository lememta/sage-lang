import Sage.Token

namespace Sage

-- Normalize all whitespace (newlines, tabs, etc.) to spaces before splitting
private def normalizeWhitespace (input : String) : String :=
  input.map (fun c => if c == '\n' || c == '\r' || c == '\t' then ' ' else c)

-- Tokenizer: splits on whitespace, matches keywords/operators
def tokenize (input : String) : List Token :=
  let words := (normalizeWhitespace input).splitOn " " |>.filter (· ≠ "")
  let tokens := words.map (fun word =>
    let tokenType := match word with
      | "@mod" => TokenType.mod
      | "@type" => TokenType.type
      | "@fn" => TokenType.fn
      | "@spec" => TokenType.spec
      | "@req" => TokenType.req
      | "@ens" => TokenType.ens
      | "@invariant" => TokenType.invariant
      | "@state" => TokenType.state
      | "@refine" => TokenType.refine
      | "@impl" => TokenType.impl
      | "@maps" => TokenType.maps
      | "@preserves" => TokenType.preserves
      -- Machine-verifiable contract keywords
      | "@effect" => TokenType.effect
      | "@decreases" => TokenType.decreases
      | "@pure" => TokenType.pure_
      | "@total" => TokenType.total
      | "@partial" => TokenType.partial_
      | "let" => TokenType.let
      | "if" => TokenType.if_
      | "else" => TokenType.else_
      | "ret" => TokenType.ret
      | "true" => TokenType.true_
      | "false" => TokenType.false_
      | "as" => TokenType.as_
      | "where" => TokenType.where_
      -- Quantifiers (ASCII)
      | "forall" => TokenType.forall_
      | "exists" => TokenType.exists_
      -- Delimiters
      | "(" => TokenType.lparen
      | ")" => TokenType.rparen
      | "{" => TokenType.lbrace
      | "}" => TokenType.rbrace
      | "[" => TokenType.lbracket
      | "]" => TokenType.rbracket
      | "," => TokenType.comma
      | ":" => TokenType.colon
      | "." => TokenType.dot
      | ";" => TokenType.semicolon
      -- Arithmetic
      | "+" => TokenType.plus
      | "-" => TokenType.minus
      | "*" => TokenType.star
      | "/" => TokenType.slash
      | "%" => TokenType.percent
      -- Assignment / comparison
      | "=" => TokenType.assign
      | "==" => TokenType.eq
      | "!=" => TokenType.ne
      | "<" => TokenType.lt
      | "<=" => TokenType.le
      | ">" => TokenType.gt
      | ">=" => TokenType.ge
      -- Logical
      | "!" => TokenType.not
      | "!!" => TokenType.important
      | "&&" => TokenType.and
      | "||" => TokenType.or
      | "&" => TokenType.amp
      | "|" => TokenType.pipe
      | "?" => TokenType.question
      -- Arrows
      | "->" => TokenType.arrow
      | "=>" => TokenType.fatArrow
      | "<-" => TokenType.leftArrow
      -- Unicode symbols
      | "✓" => TokenType.checkmark
      | "✗" => TokenType.crossmark
      | "∀" => TokenType.forall_
      | "∃" => TokenType.exists_
      | "∈" => TokenType.elementOf
      | "⟹" => TokenType.fatArrow
      | "∑" => TokenType.summation
      | _ => TokenType.identifier -- Default to identifier for now
    ⟨tokenType, word, 1, 1⟩)
  tokens ++ [⟨TokenType.eof, "", 1, 1⟩]

end Sage
