import Sage
import Sage.LSP.Types

open Sage SageLSP

namespace SageLSP

def analyzeSage (text : String) : List Diagnostic := Id.run do
  let tokens := tokenize text
  match parse tokens with
  | none =>
    [{ range := { start := ⟨0, 0⟩, «end» := ⟨0, 0⟩ }
       severity := DiagnosticSeverity.error.toNat
       message := "Parse error" }]
  | some prog =>
    match typeCheck prog with
    | .error msg =>
      [{ range := { start := ⟨0, 0⟩, «end» := ⟨0, 0⟩ }
         severity := DiagnosticSeverity.error.toNat
         message := msg }]
    | .ok _ => []

def tokenToDiagnostic (tok : Token) (msg : String) : Diagnostic :=
  { range := { start := ⟨tok.line - 1, tok.column - 1⟩
               «end» := ⟨tok.line - 1, tok.column + tok.value.length⟩ }
    severity := DiagnosticSeverity.error.toNat
    message := msg }

end SageLSP
