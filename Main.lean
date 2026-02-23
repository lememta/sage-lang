import Sage

open Sage

def severityStr : Severity → String
  | .error => "ERROR"
  | .warning => "WARN"
  | .info => "INFO"

def main (args : List String) : IO UInt32 := do
  match args with
  | [] =>
    IO.println "Usage: sage <file.sage>"
    pure 1
  | filename :: _ =>
    let content ← IO.FS.readFile filename
    match compile content with
    | .ok result =>
      IO.println s!"Compiled successfully: {result.program.modules.length} module(s)"
      for m in result.program.modules do
        IO.println s!"Module: {m.name}"
        IO.println s!"  Types: {m.types.length}"
        IO.println s!"  Functions: {m.functions.length}"
        -- Show contract and effect summaries per function
        for f in m.functions do
          if !f.effects.isEmpty || !f.requires.isEmpty || !f.ensures.isEmpty || f.decreases.isSome then
            IO.println s!"    {f.name}:"
            if !f.requires.isEmpty then
              IO.println s!"      Preconditions: {f.requires.length}"
            if !f.ensures.isEmpty then
              IO.println s!"      Postconditions: {f.ensures.length}"
            if !f.effects.isEmpty then
              IO.println s!"      Effects: {f.effects.length} declared"
            if f.decreases.isSome then
              IO.println s!"      Termination: measure provided"
        for t in m.types do
          if !t.invariants.isEmpty then
            IO.println s!"    {t.name}: {t.invariants.length} invariant(s)"
      -- Show verification results
      if result.verification.messages.isEmpty then
        IO.println "Verification: All checks passed ✓"
      else
        IO.println "--- Verification Results ---"
        let errors := result.verification.messages.filter (·.severity == .error)
        let warnings := result.verification.messages.filter (·.severity == .warning)
        let infos := result.verification.messages.filter (·.severity == .info)
        for msg in errors do
          IO.println s!"  [{severityStr msg.severity}] {msg.location}: {msg.message}"
        for msg in warnings do
          IO.println s!"  [{severityStr msg.severity}] {msg.location}: {msg.message}"
        for msg in infos do
          IO.println s!"  [{severityStr msg.severity}] {msg.location}: {msg.message}"
        if errors.isEmpty then
          IO.println s!"  Summary: {infos.length} verified, {warnings.length} warning(s), 0 error(s) ✓"
        else
          IO.println s!"  Summary: {errors.length} error(s), {warnings.length} warning(s)"
      pure 0
    | .error msg =>
      IO.println s!"Error: {msg}"
      pure 1
