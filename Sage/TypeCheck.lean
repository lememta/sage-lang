import Sage.AST

namespace Sage

-- Very simple type checker that just validates basic structure
def typeCheck (prog : Program) : Except String Unit :=
  -- Basic validation that the program structure is valid
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

  -- Return result
  if funcErrors.isEmpty then
    Except.ok ()
  else
    Except.error (String.intercalate "\n" funcErrors)

end Sage
