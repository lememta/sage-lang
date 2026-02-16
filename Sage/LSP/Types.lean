import Sage
import Lean.Data.Json
import Lean.Data.Json.FromToJson

open Sage Lean

namespace SageLSP

structure Position where
  line : Nat
  character : Nat
  deriving ToJson, FromJson

structure Range where
  start : Position
  «end» : Position
  deriving ToJson, FromJson

structure Location where
  uri : String
  range : Range
  deriving ToJson, FromJson

structure Diagnostic where
  range : Range
  severity : Nat
  message : String
  deriving ToJson, FromJson

structure TextDocumentIdentifier where
  uri : String
  deriving ToJson, FromJson

structure TextDocumentItem where
  uri : String
  languageId : String
  version : Nat
  text : String
  deriving ToJson, FromJson

inductive DiagnosticSeverity where
  | error : DiagnosticSeverity
  | warning : DiagnosticSeverity
  | information : DiagnosticSeverity
  | hint : DiagnosticSeverity

def DiagnosticSeverity.toNat : DiagnosticSeverity → Nat
  | error => 1
  | warning => 2
  | information => 3
  | hint => 4

structure DocumentState where
  uri : String
  text : String
  version : Nat
  diagnostics : List Diagnostic := []
  deriving Inhabited

def DocumentState.update (doc : DocumentState) (text : String) (version : Nat) : DocumentState :=
  { doc with text := text, version := version }

end SageLSP
