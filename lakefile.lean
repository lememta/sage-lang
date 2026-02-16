import Lake
open Lake DSL

package «sage» where
  version := v!"0.1.0"

lean_lib «Sage» where

@[default_target]
lean_exe «sage» where
  root := `Main

lean_exe «sage-lsp» where
  root := `MainLSP

lean_exe «test» where
  root := `Test
