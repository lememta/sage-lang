import Sage.Token
import Sage.Lexer
import Sage.AST
import Sage.Parser
import Sage.TypeCheck

namespace Sage

def compile (input : String) : Except String Program := do
  let tokens := tokenize input
  match parse tokens with
  | none => throw "Parse error"
  | some prog =>
    typeCheck prog
    pure prog

end Sage
