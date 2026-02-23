namespace Sage

inductive TokenType where
  | mod | use | type | fn | spec | refine | test | impl
  | req | ens | invariant | state | init | ops
  | decisions | maps | preserves
  | given | when | then | validates
  | let | if_ | else_ | for_ | in_ | match_ | ret
  | string | number | true_ | false_
  | identifier | typeName
  | arrow | fatArrow | leftArrow | assign
  | plus | minus | star | slash | percent
  | eq | ne | lt | le | gt | ge
  | and | or | not | pipe | amp | question
  | lparen | rparen | lbrace | rbrace | lbracket | rbracket
  | comma | colon | dot | semicolon
  | important | as_ | checkmark | crossmark
  -- Machine-verifiable contracts tokens
  | effect | decreases | pure_ | total | partial_
  | forall_ | exists_ | elementOf | summation
  | where_
  | eof
  deriving Repr, BEq, Inhabited

structure Token where
  type : TokenType
  value : String
  line : Nat
  column : Nat
  deriving Repr, Inhabited

end Sage
