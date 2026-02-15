# SAGE Language Specification

A semi-formal language for LLM-assisted development with multiple formality levels.

## Design Philosophy

SAGE works at multiple levels of formality:
- **Level 0**: Natural language only (quickest, AI-friendly)
- **Level 1**: Structured specs (types + contracts, no refinement)
- **Level 2**: Explicit refinement (when precision matters)
- **Level 3**: Full formal verification (mission-critical systems)

Users choose their level. SAGE scales with needs.

## Syntax Reference

### Natural Language
- Strings in double quotes: `"Build a user authentication system"`
- Implementation decisions prefixed with `!!`: `!! "Use bcrypt for hashing"`
- Section separators: `---`

### Module Declaration
```
@mod module_name
"Module description"
```

### Type Definitions
```
@type TypeName = {
  field1: Type1,
  field2: Type2
}
```

Built-in types: `Str`, `Int`, `Bool`, `Time`, `Date`, `Money`, `Result<T>`, `Set<T>`, `Map<K,V>`

### Function Definitions
```
@fn function_name(param1: Type1, param2: Type2) -> ReturnType
"Function description"
@req precondition1
@req precondition2  
@ens "postcondition description"

"Step description"
let variable = expression
if condition => body
ret value
```

### Specifications (Level 2+)
```
@spec SpecName
"Specification description"
@property "Property description"
@state
  field1: Type1
  field2: Type2
@invariant expression
@invariant ∀ x ∈ collection: predicate(x)
```

### Operations
```
@op operation_name(params) -> ReturnType
@req precondition
@ens postcondition
@ens result' = expression  // prime notation for post-state
```

### Refinements
```
@refine ParentSpec as ChildSpec
@decision "Design decision" !!
@maps "How concrete maps to abstract"
@preserves "What invariants are maintained"
```

### Alternatives
```
@refine Spec as Alternative1 [alternative]
@compare_with Alternative2
  advantages: "..."
  disadvantages: "..."
```

### Implementations
```
@impl SpecName
... code ...
```

### Inferred Annotations (tool-generated)
```
@inferred_req condition ← "Reason"
@inferred_ens "effect" ← "Reason"  
@inferred_effect "side effect" ← "Reason"
```

## Operators & Symbols

- `->` return type arrow
- `=>` if-then arrow
- `?` error propagation (like Rust)
- `!!` implementation decision marker
- `∀` universal quantifier
- `∃` existential quantifier  
- `∈` set membership
- `⟹` logical implication
- `'` prime notation (post-state)
- `∑` summation
- `✓` verification checkmark

## Control Flow

```
if condition => expression
if condition => expression1
   else => expression2

let binding = value
ret value
```

## Comments

Natural language strings serve as comments:
```
"This is a comment describing the next section"
```

## File Extension

`.sage`

## Examples

See the full specification document for examples at each formality level.
