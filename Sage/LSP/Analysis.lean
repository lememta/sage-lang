import Sage
import Sage.LSP.Types

open Sage SageLSP

namespace SageLSP

-- Map verification severity to LSP diagnostic severity
private def verifySeverityToLSP : Sage.Severity → Nat
  | .error => DiagnosticSeverity.error.toNat
  | .warning => DiagnosticSeverity.warning.toNat
  | .info => DiagnosticSeverity.information.toNat

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
    | .ok _ =>
      -- Run machine verification and report diagnostics
      let verifyResult := verifyProgram prog
      verifyResult.messages.map (fun vmsg =>
        { range := { start := ⟨0, 0⟩, «end» := ⟨0, 0⟩ }
          severity := verifySeverityToLSP vmsg.severity
          message := s!"[{vmsg.location}] {vmsg.message}" })

-- Per-function verification: parse, find the function, verify just that one, return JSON
def analyzeSageFunction (text : String) (moduleName funcName : String) : Lean.Json := Id.run do
  let tokens := tokenize text
  match parse tokens with
  | none =>
    Lean.Json.mkObj [
      ("status", Lean.Json.str "error"),
      ("messages", Lean.Json.arr #[Lean.Json.mkObj [
        ("severity", Lean.Json.num 1),
        ("message", Lean.Json.str "Parse error")
      ]])]
  | some prog =>
      -- Skip whole-program typeCheck for per-function verification;
      -- the verifier catches the same issues on a per-function basis.
      -- Find the target module
      match prog.modules.find? (fun m => m.name == moduleName) with
      | none =>
        Lean.Json.mkObj [
          ("status", Lean.Json.str "error"),
          ("messages", Lean.Json.arr #[Lean.Json.mkObj [
            ("severity", Lean.Json.num 1),
            ("message", Lean.Json.str s!"Module '{moduleName}' not found")
          ]])]
      | some mod =>
        -- Find the target function
        match mod.functions.find? (fun f => f.name == funcName) with
        | none =>
          Lean.Json.mkObj [
            ("status", Lean.Json.str "error"),
            ("messages", Lean.Json.arr #[Lean.Json.mkObj [
              ("severity", Lean.Json.num 1),
              ("message", Lean.Json.str s!"Function '{funcName}' not found in module '{moduleName}'")
            ]])]
        | some func =>
          -- Build verification environment
          let globalEnv : VerifyEnv := {
            functionEffects := concatMap prog.modules (fun m =>
              m.functions.map (fun f => (f.name, f.effects)))
            typeInvariants := concatMap prog.modules (fun m =>
              m.types.filterMap (fun t =>
                if t.invariants.isEmpty then none
                else some (t.name, t.invariants)))
          }
          let modEnv : VerifyEnv := {
            globalEnv with
            functionEffects := globalEnv.functionEffects ++
              mod.functions.map (fun f => (f.name, f.effects))
            typeInvariants := globalEnv.typeInvariants ++
              mod.types.filterMap (fun t =>
                if t.invariants.isEmpty then none
                else some (t.name, t.invariants))
          }
          -- Run verification on the single function
          let result := verifyFunction modEnv func mod.name
          let status := if result.hasErrors then "failed" else "verified"
          let messageJsons := result.messages.map (fun vmsg =>
            Lean.Json.mkObj [
              ("severity", Lean.Json.num (verifySeverityToLSP vmsg.severity)),
              ("location", Lean.Json.str vmsg.location),
              ("message", Lean.Json.str vmsg.message)
            ])
          Lean.Json.mkObj [
            ("status", Lean.Json.str status),
            ("messages", Lean.Json.arr messageJsons.toArray)
          ]

def tokenToDiagnostic (tok : Token) (msg : String) : Diagnostic :=
  { range := { start := ⟨tok.line - 1, tok.column - 1⟩
               «end» := ⟨tok.line - 1, tok.column + tok.value.length⟩ }
    severity := DiagnosticSeverity.error.toNat
    message := msg }

end SageLSP
