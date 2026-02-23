import Sage.AST

namespace Sage

-- Structural type checker: validates basic program structure
-- Machine verification of contracts, effects, and termination is in Sage/Verify.lean
def typeCheck (prog : Program) : Except String Unit :=
  let errors : List String := []

  -- Check that all modules have valid names
  let moduleErrors := prog.modules.foldl (fun acc module =>
    if module.name.isEmpty then
      acc ++ ["Module name cannot be empty"]
    else
      acc
  ) errors

  -- Check that all type declarations have valid names
  let typeErrors := prog.modules.foldl (fun acc module =>
    module.types.foldl (fun typeAcc typeDecl =>
      if typeDecl.name.isEmpty then
        typeAcc ++ [s!"Type declaration name cannot be empty in module {module.name}"]
      else
        typeAcc
    ) acc
  ) moduleErrors

  -- Check that all function declarations have valid names
  let funcErrors := prog.modules.foldl (fun acc module =>
    module.functions.foldl (fun funcAcc func =>
      if func.name.isEmpty then
        funcAcc ++ [s!"Function name cannot be empty in module {module.name}"]
      else
        funcAcc
    ) acc
  ) typeErrors

  -- 8.1: Check refinement types have valid structure
  let refinementErrors := prog.modules.foldl (fun acc module =>
    module.types.foldl (fun typeAcc typeDecl =>
      match typeDecl.definition with
      | .refined varName _ _ =>
        if varName.isEmpty then
          typeAcc ++ [s!"Refinement type '{typeDecl.name}' in module '{module.name}' has empty bound variable"]
        else
          typeAcc
      | _ => typeAcc
    ) acc
  ) funcErrors

  -- 8.4: Check effect annotations are not contradictory
  let effectErrors := prog.modules.foldl (fun acc module =>
    module.functions.foldl (fun funcAcc func =>
      let hasPure := func.effects.any (· == Effect.pure)
      let hasImpure := func.effects.any (fun e => e != Effect.pure)
      if hasPure && hasImpure then
        funcAcc ++ [s!"Function '{func.name}' in module '{module.name}' declares @pure alongside impure effects"]
      else
        funcAcc
    ) acc
  ) refinementErrors

  if effectErrors.isEmpty then
    Except.ok ()
  else
    Except.error (String.intercalate "\n" effectErrors)

end Sage
