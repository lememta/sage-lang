import Sage.LSP

open SageLSP

def main : IO UInt32 := do
  IO.eprintln "SAGE Language Server starting..."
  runServer
  pure 0
