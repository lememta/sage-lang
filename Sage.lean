import Sage.Token
import Sage.Lexer
import Sage.AST
import Sage.Parser
import Sage.TypeCheck
import Sage.Verify

namespace Sage

-- Compilation result includes both the program AST and verification results
structure CompileResult where
  program : Program
  verification : VerifyResult
  deriving Inhabited

-- Full compilation pipeline: lex → parse → typeCheck → verify
def compile (input : String) : Except String CompileResult := do
  let tokens := tokenize input
  match parse tokens with
  | none => throw "Parse error"
  | some prog =>
    typeCheck prog
    let verifyResult := verifyProgram prog
    pure { program := prog, verification := verifyResult }

end Sage
