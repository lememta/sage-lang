import Sage.Token

namespace Sage

-- Minimal working tokenizer
def tokenize (input : String) : List Token :=
  let words := input.splitOn " " |>.filter (· ≠ "")
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
      | "let" => TokenType.let
      | "if" => TokenType.if_
      | "else" => TokenType.else_
      | "ret" => TokenType.ret
      | "true" => TokenType.true_
      | "false" => TokenType.false_
      | "as" => TokenType.as_
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
      | "+" => TokenType.plus
      | "-" => TokenType.minus
      | "*" => TokenType.star
      | "/" => TokenType.slash
      | "%" => TokenType.percent
      | "=" => TokenType.assign
      | "==" => TokenType.eq
      | "!=" => TokenType.ne
      | "<" => TokenType.lt
      | "<=" => TokenType.le
      | ">" => TokenType.gt
      | ">=" => TokenType.ge
      | "!" => TokenType.not
      | "!!" => TokenType.important
      | "&&" => TokenType.and
      | "||" => TokenType.or
      | "&" => TokenType.amp
      | "|" => TokenType.pipe
      | "?" => TokenType.question
      | "->" => TokenType.arrow
      | "=>" => TokenType.fatArrow
      | "<-" => TokenType.leftArrow
      | "✓" => TokenType.checkmark
      | "✗" => TokenType.crossmark
      | _ => TokenType.identifier -- Default to identifier for now
    ⟨tokenType, word, 1, 1⟩)
  tokens ++ [⟨TokenType.eof, "", 1, 1⟩]

end Sage
