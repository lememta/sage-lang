# 🌿 SAGE

**S**emi-formal **A**I-**G**uided **E**ngineering Language

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)
[![VS Code](https://img.shields.io/badge/VS%20Code-Extension-blueviolet.svg)](packages/vscode)

> A specification language that scales from napkin sketches to formal verification. Write specs the way you think — SAGE meets you where you are.

## Why SAGE?

Most spec languages force a choice: stay informal (and imprecise) or go formal (and slow). SAGE says **why not both?**

```sage
# Level 0: Quick idea
"Build user auth with email/password"
"Rate limit login attempts"
!! "Use bcrypt"

# Level 1: Add structure when ready
@fn login(email: Str, password: Str) -> Result<Session>
@req email.is_valid()
@ens "Session created on success"

# Level 2: Go formal when it matters
@invariant ∀ s ∈ sessions: ∃ u ∈ users: s.user_id = u.id
```

**Start informal. Formalize incrementally. SAGE grows with your needs.**

## Features

- 📝 **Natural language first** — Quoted strings are valid specs
- 🔧 **Structured when needed** — Types, functions, contracts
- 🔬 **Formal when critical** — Invariants, refinements, proofs
- 🤖 **LLM-friendly** — Designed for AI-assisted development
- ✨ **VS Code support** — Syntax highlighting out of the box

## Installation

```bash
# Clone and install
git clone https://github.com/yourusername/sage-lang.git
cd sage-lang
pnpm install
pnpm build
```

### VS Code Extension

```bash
cd packages/vscode
npx @vscode/vsce package --no-dependencies
code --install-extension sage-vscode-0.1.0.vsix
```

## Quick Start

### Using the Parser

```typescript
import { parse } from '@sage-lang/parser';

const ast = parse(`
@mod todo_app

@type Task = {
  id: Int,
  title: Str,
  completed: Bool
}

@fn create_task(title: Str) -> Result<Task>
@req title.len() > 0 && title.len() < 200
@ens "Task is created with completed = false"
`);

console.log(ast);
```

### Writing SAGE Specs

Create a `.sage` file:

```sage
@mod payment_service
"Handle money transfers securely"

@type Account = {
  id: Str,
  balance: Money
}

@fn transfer(from: Account, to: Account, amount: Money) -> Result<()>
"Move money between accounts"
@req amount > 0
@req from.balance >= amount
@ens from.balance' = from.balance - amount
@ens to.balance' = to.balance + amount

!! "Use database transactions"
!! "Log all transfers for audit"
```

## Formality Levels

| Level | Use When | Constructs |
|-------|----------|------------|
| **0 — Natural** | Quick ideas, prototypes | `"quoted strings"`, `!!` decisions |
| **1 — Structured** | Production code | `@type`, `@fn`, `@req`, `@ens` |
| **2 — Formal** | Critical systems | `@spec`, `@invariant`, `@refine`, `@preserves` |

See [`examples/`](examples/) for complete files at each level.

## Syntax Reference

### Core Constructs

| Syntax | Purpose | Example |
|--------|---------|---------|
| `@mod name` | Module declaration | `@mod user_auth` |
| `@type Name = {...}` | Type definition | `@type User = { email: Str }` |
| `@fn name(...) -> T` | Function signature | `@fn login(email: Str) -> Result<Session>` |
| `@req condition` | Precondition | `@req amount > 0` |
| `@ens condition` | Postcondition | `@ens "User created"` |
| `"string"` | Natural language / comment | `"Validate the input"` |
| `!!` | Implementation decision | `!! "Use Redis for caching"` |
| `---` | Section separator | |

### Formal Constructs

| Syntax | Purpose | Example |
|--------|---------|---------|
| `@spec Name` | Specification block | `@spec PaymentSystem` |
| `@state` | State declaration | `@state accounts: Map<Id, Account>` |
| `@invariant` | Invariant expression | `@invariant ∀ a ∈ accounts: a.balance >= 0` |
| `@refine A as B` | Refinement | `@refine Spec as ConcreteImpl` |
| `@decision` | Design decision | `@decision "Use 2PC for distributed txns"` |
| `@preserves` | Preserved properties | `@preserves ✓ "Money conservation"` |
| `@impl` | Implementation block | `@impl ConcreteImpl` |

### Control Flow

```sage
let result = some_call()
if condition => ret Err("failed")
ret Ok(value)
```

### Math Symbols

SAGE supports mathematical notation: `∀` `∃` `∈` `⟹` `∑` `'` (prime for post-state)

## Project Structure

```
sage-lang/
├── packages/
│   ├── parser/          # TypeScript parser (lexer + AST)
│   │   ├── src/
│   │   │   ├── lexer.ts
│   │   │   ├── parser.ts
│   │   │   └── ast.ts
│   │   └── dist/        # Compiled output
│   └── vscode/          # VS Code extension
│       ├── syntaxes/
│       │   └── sage.tmLanguage.json
│       └── language-configuration.json
├── examples/            # Sample .sage files
│   ├── level0-natural.sage
│   ├── level1-structured.sage
│   ├── level2-formal.sage
│   └── inferred.sage
├── SAGE_SPEC.md         # Language specification
└── DESIGN.md            # Design philosophy & examples
```

## Development

```bash
# Install dependencies
pnpm install

# Build everything
pnpm build

# Build just the parser
pnpm build:parser

# Run tests
pnpm test
```

## Documentation

- **[Tutorial](docs/tutorial.md)** — Learn SAGE in 15 minutes with hands-on examples
- **[Token Efficiency](docs/token-efficiency.md)** — Why SAGE uses 38% fewer tokens
- **[AGENT.md](AGENT.md)** — Instructions for LLMs to understand SAGE
- **[SKILL.md](SKILL.md)** — OpenClaw-compatible skill file
- **[SAGE_SPEC.md](SAGE_SPEC.md)** — Language specification
- **[DESIGN.md](DESIGN.md)** — Design philosophy and examples

## Roadmap

- [ ] Language Server Protocol (LSP) for VS Code
- [ ] CLI tool for parsing and validation
- [ ] Integration with popular LLMs
- [ ] Code generation backends (TypeScript, Python, Rust)
- [ ] Formal verification tooling

## Philosophy

> "Refinement is POWER, not BURDEN. Use it when it helps. Skip it when it doesn't."

SAGE believes:
- **Natural language is valid** — Don't force formality before it's needed
- **Incrementalism works** — Start simple, add rigor over time
- **AI is a partner** — Design for human-AI collaboration
- **Decisions matter** — Track the "why" with `!!` and `@decision`

## Contributing

Contributions welcome! Please read the design docs first:
- [SAGE_SPEC.md](SAGE_SPEC.md) — Language specification
- [DESIGN.md](DESIGN.md) — Design philosophy and examples

## License

MIT © 2026
