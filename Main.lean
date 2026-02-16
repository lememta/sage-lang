import Sage

open Sage

def main (args : List String) : IO UInt32 := do
  match args with
  | [] =>
    IO.println "Usage: sage <file.sage>"
    pure 1
  | filename :: _ =>
    let content ← IO.FS.readFile filename
    match compile content with
    | .ok prog =>
      IO.println s!"Compiled successfully: {prog.modules.length} module(s)"
      for m in prog.modules do
        IO.println s!"Module: {m.name}"
        IO.println s!"  Types: {m.types.length}"
        IO.println s!"  Functions: {m.functions.length}"
      pure 0
    | .error msg =>
      IO.println s!"Error: {msg}"
      pure 1
