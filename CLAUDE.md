# CLAUDE.md — SAGE Language Repository Guide

## What is SAGE?

**SAGE** (Semi-formal AI-Guided Engineering Language) is a 3-level specification language designed for human-AI collaboration. It lets developers write specifications at any formality level — from pure natural language to formal mathematical specifications — and have AI assistants generate precise implementations from them.

SAGE does **not** compile to executable code. Instead, the compiler validates and normalizes `.sage` specifications. The actual code generation is performed externally by LLMs that consume the validated AST.

## Technology Stack

- **Language**: Lean 4 (pure functional proof assistant)
- **Build system**: Lake (Lean's package manager)
- **Package version**: 0.1.0
- **VS Code extension**: Node.js + vscode-languageclient v8.1.0
- **License**: MIT (Copyright 2026 Gheghen)

## Repository Structure

```
sage-lang/
├── lakefile.lean            # Lake build config (3 targets: sage, sage-lsp, test)
├── Sage.lean                # Root module — exports everything, defines compile function
├── Main.lean                # CLI entry point: reads .sage file, prints module info
├── MainLSP.lean             # LSP server entry point
├── Test.lean                # Test framework + runner
│
├── Sage/                    # Core compiler (6 files, ~900 lines total)
│   ├── Token.lean           # TokenType inductive (70+ variants) + Token structure
│   ├── Lexer.lean           # tokenize: whitespace-split + keyword matching
│   ├── AST.lean             # SageType, Expr, Stmt, Function, TypeDecl, Module, Program + Effect, VerifyResult
│   ├── Parser.lean          # Recursive descent parser (~280 lines)
│   ├── TypeCheck.lean       # Structural validation (~60 lines)
│   ├── Verify.lean          # Machine-verifiable contract verification engine (~300 lines)
│   └── LSP/
│       ├── Types.lean       # LSP protocol types (Position, Range, Diagnostic, etc.)
│       ├── Analysis.lean    # analyzeSage: runs full pipeline, returns diagnostics
│       └── Server.lean      # JSON-RPC server over stdio (~170 lines)
│
├── Test/                    # Test suites (4 files)
│   ├── Lexer.lean           # Token recognition tests
│   ├── Parser.lean          # Parsing tests for all constructs
│   ├── TypeChecker.lean     # Validation tests
│   └── Integration.lean     # Full pipeline tests (lex → parse → typecheck)
│
├── examples/                # 5 example .sage files
│   ├── level0-natural.sage  # Pure natural language (auth system)
│   ├── level1-structured.sage # Types + contracts (auth system)
│   ├── level2-formal.sage   # Formal spec with refinement (payment processor)
│   ├── inferred.sage        # Inferred specifications demo
│   └── verified-contracts.sage # Machine-verifiable contracts demo
│
├── vscode-extension/        # VS Code extension
│   ├── package.json         # Extension manifest
│   ├── client/extension.js  # LSP client (looks for .lake/build/bin/sage-lsp)
│   ├── syntaxes/sage.tmLanguage.json  # TextMate grammar
│   └── language-configuration.json
│
├── scripts/
│   ├── setup-vscode-lsp.sh  # VS Code extension installer
│   └── token-compare.js     # Token efficiency comparison tool
│
├── docs/
│   ├── tutorial.md           # Step-by-step user tutorial
│   └── token-efficiency.md   # Token usage analysis
│
├── DESIGN.md                # Design philosophy document (467 lines)
├── SAGE_SPEC.md             # Language specification reference
├── AGENT.md                 # Instructions for LLMs interpreting SAGE
├── SKILL.md                 # Claude Code skill definition
├── QUICKSTART.md            # Setup guide
├── USAGE.md                 # Detailed usage guide
├── README.md                # Project overview
└── build.sh                 # Builds sage + sage-lsp
```

## Build Commands

```bash
lake build sage          # Compiler CLI → .lake/build/bin/sage
lake build sage-lsp      # LSP server → .lake/build/bin/sage-lsp
lake build test          # Test suite → .lake/build/bin/test
lake build               # All targets
lake clean               # Clean build artifacts
./build.sh               # Convenience: builds sage + sage-lsp
```

Run tests:
```bash
.lake/build/bin/test
```

Run compiler:
```bash
.lake/build/bin/sage examples/level1-structured.sage
```

## Compiler Pipeline

```
Source (.sage) → tokenize → parse → typeCheck → verify → CompileResult (Program + VerifyResult)
```

Defined in `Sage.lean`:
```lean
structure CompileResult where
  program : Program
  verification : VerifyResult

def compile (input : String) : Except String CompileResult := do
  let tokens := tokenize input
  match parse tokens with
  | none => throw "Parse error"
  | some prog =>
    typeCheck prog
    let verifyResult := verifyProgram prog
    pure { program := prog, verification := verifyResult }
```

### Lexer (`Sage/Lexer.lean`)
- **Strategy**: Normalizes all whitespace (newlines, tabs) to spaces, splits, matches against 70+ keywords/operators
- **Limitation**: No character-level scanning — tokens must be whitespace-separated
- **Line/column tracking**: Hardcoded to (1, 1) — not yet position-aware
- **Fallback**: Unrecognized words default to `TokenType.identifier`

### Parser (`Sage/Parser.lean`)
- **Strategy**: Recursive descent with `partial def` functions
- **Key functions**:
  - `parse` → `parseTokensToModules` → `parseModuleTokens` → `parseModuleBodyTokens`
  - `parseTypeTokens`: Parses `@type Name = ...` including refinement types and `@invariant`
  - `parseFunctionTokens`: Parses `@fn name(params) -> Type` with contracts, effects, termination
  - `parseFunctionBodyTokens`: Parses `@req`, `@ens`, `@effect`, `@decreases`, `@pure`, `let`, `ret`, natural text
  - `parseRefinementType`: Parses `{ x : T | predicate }` syntax
  - `parseExprTokens`: Parses expressions including `∀`/`∃` quantifiers, `⟹` implication, `∈` membership
- **Simplifications**: Parameter parsing skips to matching `)` without parsing individual params. Struct types parsed as `SageType.struct []` (empty fields). Standalone natural language creates a "default" module.

### Type Checker (`Sage/TypeCheck.lean`)
- **Scope**: Validates non-empty names, refinement type structure, effect annotation consistency
- **Error handling**: Accumulates all errors, returns `Except String Unit`
- **Catches**: empty names, empty refinement variables, contradictory `@pure` + impure effects

### Verification Engine (`Sage/Verify.lean`) — NEW
- **Purpose**: Machine verification of contracts, effects, invariants, and termination
- **5 verification passes**:
  1. **Refinement types (8.1)**: Checks predicates reference bound variables, detects trivially true/false predicates, validates base type names
  2. **Pre/post conditions (8.2)**: Detects contradictory preconditions, checks parameter references, identifies trivially false conditions, verifies simple implications
  3. **Data structure invariants (8.3)**: Checks invariant consistency, detects trivially true/false invariants, warns when functions returning invariant-bearing types lack postconditions
  4. **Effect tracking (8.4)**: Detects contradictory effects (e.g., `@pure` + `@effect IO`), duplicate effects, verifies pure functions don't call effectful functions
  5. **Termination proofs (8.5)**: Requires `@decreases` on recursive functions, validates measure isn't constant, checks measure references parameters
- **Output**: `VerifyResult` with error/warning/info messages, integrated into CLI output and LSP diagnostics

## AST Structure (`Sage/AST.lean`)

```
Program
  └── Module (name, imports, types, functions, naturalText)
        ├── TypeDecl (name, SageType, invariants)
        │     └── SageType: name | generic | struct | union | arrow | refined
        └── Function (name, params, returnType, requires, ensures, contracts, effects, decreases, body)
              ├── Expr: lit | num | bool | ident | binOp | unOp | call | member | list | structLit
              │         | forall_ | exists_ | implies | elementOf
              ├── Stmt: naturalText(+importance) | letBind | ret | if_ | expr
              ├── Effect: io | mutation | exception | diverge | pure
              └── Contract (kind, expr, description, status)
```

Additional types: `VerifyResult`, `VerifyMessage`, `Severity`, `VerifyStatus`, `VerifyEnv`.
All types derive `Repr, BEq, Inhabited`.

## LSP Server (`Sage/LSP/Server.lean`)

- **Transport**: JSON-RPC 2.0 over stdin/stdout
- **State**: `ServerState` holds a list of `DocumentState` (uri, text, version, diagnostics)
- **Supported methods**:
  - `initialize` — returns capabilities (textDocumentSync=1, diagnosticProvider)
  - `shutdown` — clean shutdown
  - `textDocument/diagnostic` — on-demand diagnostics via `analyzeSage`
  - `textDocument/didOpen` — stores doc + runs analysis
  - `textDocument/didChange` — updates doc text + re-analyzes
  - `textDocument/didClose` — removes doc from state
- **Diagnostics**: Runs full compile pipeline; parse errors and type errors reported with severity and position

## Machine-Verifiable Contracts

The verification engine (`Sage/Verify.lean`) performs 5 categories of checks:

### 8.1 Refinement Types
```sage
@type PosInt = { x : Int | x > 0 }
@type NonEmpty = { s : String | s.len > 0 }
```
- Predicate must reference the bound variable
- Trivially true predicates warn (useless refinement)
- Trivially false predicates error (uninhabitable type)

### 8.2 Pre/Post Conditions
```sage
@fn transfer @req amount > 0 @ens balance >= 0 -> Result
@fn validate @req ∀ x : Int, x > 0 @ens "Input is validated" -> Bool
```
- Contradictory preconditions are detected
- Contract expressions are checked against declared parameter names
- Postconditions matching preconditions are flagged as verified

### 8.3 Data Structure Invariants
```sage
@type Balance = Int @invariant balance >= 0
```
- Invariants are checked for consistency (no contradictions)
- Functions returning a type with invariants but lacking `@ens` trigger a warning
- Invariant + refinement predicate contradictions are detected

### 8.4 Effect Tracking
```sage
@fn readFile @effect IO -> String
@fn add @pure -> Int
@fn transfer @effect IO @effect Mutation -> Bool
```
- `@pure` + any impure effect = error
- Duplicate effects warn
- Pure functions calling effectful functions = error
- Effects propagated through call graph analysis

### 8.5 Termination Proofs
```sage
@fn factorial @decreases n -> Nat
```
- Recursive functions without `@decreases` = error
- Constant measures (numeric/boolean/string literals) = error
- Measure must reference function parameters
- Non-recursive functions with `@decreases` warn (unnecessary)

## SAGE Language Syntax

### Three Formality Levels

**Level 0 — Natural Language**:
```sage
"Build a user authentication system"
!! "Use bcrypt for hashing"
```

**Level 1 — Structured** (types + contracts + natural language):
```sage
@mod user_auth
@type User = { email: Str, password_hash: Str }
@fn register(email: Str, password: Str) -> Result<User>
  @req email.is_valid() && password.len() >= 8
  @ens "User is created with hashed password"
```

**Level 2 — Formal** (specs, invariants, refinement):
```sage
@spec PaymentProcessor
  @state accounts: Map<AccountId, Balance>
  @invariant ∑ accounts.values() = TOTAL_MONEY
@refine PaymentProcessor as DistributedPayment
  @decision "Use 2-phase commit" !!
  @preserves ✓ "Money conservation"
```

### Key Syntax Elements

| Syntax | Purpose |
|--------|---------|
| `@mod name` | Module declaration |
| `@type Name = definition` | Type declaration |
| `@fn name(params) -> Type` | Function signature |
| `@spec Name` | Specification block |
| `@req expression` | Precondition (requires) |
| `@ens expression` | Postcondition (ensures) |
| `@invariant expression` | Invariant constraint |
| `@refine Parent as Child` | Refinement relationship |
| `@decision "text" !!` | Implementation decision (tracked) |
| `@preserves ✓ "property"` | Verified preservation |
| `@impl SpecName` | Implementation block |
| `"quoted text"` | Natural language requirement (binding) |
| `!! "text"` | Important decision marker |
| `---` | Section separator |
| `@effect IO\|Mutation\|Exception\|Diverge` | Effect annotation (8.4) |
| `@pure` | Shorthand for `@effect Pure` (8.4) |
| `@decreases expr` | Termination measure (8.5) |
| `{ x : T \| P(x) }` | Refinement type (8.1) |
| `∀ x : T, P(x)` / `forall` | Universal quantifier in contracts |
| `∃ x : T, P(x)` / `exists` | Existential quantifier in contracts |

### Built-in Types
Primitives: `Str`, `Int`, `Bool`, `Time`, `Date`, `Money`, `()`
Generic: `Result<T>`, `Option<T>`, `Set<T>`, `Map<K,V>`, `List<T>`

### Operators and Symbols
- Arrows: `->`, `=>`, `<-`
- Math: `∀`, `∃`, `∈`, `⟹`, `∑`
- State: `'` (post-state, e.g., `accounts'`)
- Status: `✓` (verified), `✗` (rejected)

## Token Types (70+)

Defined in `Sage/Token.lean` as `inductive TokenType`:
- **Keywords**: mod, use, type, fn, spec, refine, test, impl
- **Contracts**: req, ens, invariant, state, init, ops
- **Refinement**: decisions, maps, preserves
- **Control**: given, when, then, validates, let, if_, else_, for_, in_, match_, ret
- **Literals**: string, number, true_, false_, identifier, typeName
- **Operators**: arrow, fatArrow, leftArrow, assign, plus, minus, star, slash, percent, eq, ne, lt, le, gt, ge, and, or, not, pipe, amp, question
- **Delimiters**: lparen, rparen, lbrace, rbrace, lbracket, rbracket
- **Punctuation**: comma, colon, dot, semicolon
- **Special**: important (!!), as_, checkmark (✓), crossmark (✗), eof
- **Verification**: effect, decreases, pure_, total, partial_, forall_, exists_, elementOf, summation, where_

## Testing

74+ unit tests organized in 4 files under `Test/`:
- **Test/Lexer.lean**: Keyword recognition, operator parsing, symbol handling
- **Test/Parser.lean**: Empty input, modules, types, functions, contracts, multi-level examples
- **Test/TypeChecker.lean**: Empty programs, name validation, complex structures
- **Test/Integration.lean**: Full pipeline tests for all 3 formality levels

Test framework (`Test.lean`) provides: `assert`, `assertEqual`, `assertSome`, `assertNone`

## Known Limitations and Simplifications

1. **Lexer is whitespace-based**: Tokens must be whitespace-separated. Newlines/tabs are normalized to spaces. No character-level scanning, no string literal parsing with spaces.
2. **No position tracking**: All tokens report line=1, column=1. LSP diagnostics point to (0,0).
3. **Parameter parsing skipped**: `parseFunctionTokens` skips from `(` to `)` without parsing individual parameters.
4. **Struct fields not parsed**: Struct types are stored as `SageType.struct []` (empty field list).
5. **Type checker validates structure only**: Checks non-empty names, refinement type structure, and effect annotation consistency. No type inference, no scope analysis, no cross-reference checking. Deeper verification is in `Verify.lean`.
6. **No code generation**: The compiler validates specs but does not emit code in any target language.
7. **No CI/CD**: No GitHub Actions or automated pipeline configured.

## Architecture Decisions

- **Lean 4 chosen** for its type safety and future potential for formal verification (proving SAGE invariants within Lean's proof system).
- **Migrated from TypeScript**: Commit 5973959 completed a full TS → Lean 4 rewrite.
- **LSP-first IDE support**: Real-time diagnostics via standard LSP protocol rather than custom tooling.
- **Natural language as first-class**: Quoted strings in `.sage` files are binding requirements, not comments.
- **Progressive formality**: Users choose their comfort level (Level 0/1/2); the system doesn't force structure.

## VS Code Extension

- **Language ID**: `sage`, file extension: `.sage`
- **LSP executable lookup order**: `./lean/.lake/build/bin/sage-lsp` → `./.lake/build/bin/sage-lsp` → PATH
- **Features**: Syntax highlighting (TextMate grammar), real-time diagnostics, bracket matching, auto-closing pairs
- **Install**: Run `scripts/setup-vscode-lsp.sh` or manually symlink the extension

## Development Workflow

1. Edit Lean files in `Sage/` or `Test/`
2. `lake build` to compile
3. `.lake/build/bin/test` to run tests
4. `.lake/build/bin/sage examples/level1-structured.sage` to test compiler
5. Restart VS Code to pick up LSP changes

## Key Files Quick Reference

| File | Lines | What it does |
|------|-------|--------------|
| `Sage/Token.lean` | 28 | 60+ token type definitions |
| `Sage/Lexer.lean` | 67 | Space-based tokenizer |
| `Sage/AST.lean` | 58 | All AST node types |
| `Sage/Parser.lean` | 251 | Recursive descent parser |
| `Sage/TypeCheck.lean` | 60 | Structural validation + effect checking |
| `Sage/Verify.lean` | 300 | Machine-verifiable contract verification engine |
| `Sage.lean` | 25 | `compile` function (pipeline orchestrator) |
| `Main.lean` | 55 | CLI entry point with verification output |
| `MainLSP.lean` | 8 | LSP server entry point |
| `Sage/LSP/Server.lean` | 169 | JSON-RPC LSP implementation |
| `Sage/LSP/Types.lean` | 64 | LSP protocol data structures |
| `Sage/LSP/Analysis.lean` | 30 | Diagnostic generation |
| `Test.lean` | ~100 | Test framework + runner |
