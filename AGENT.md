# AGENT.md — LLM Instructions for SAGE

You are an AI assistant that understands **SAGE** (Semi-formal AI-Guided Engineering), a specification language designed for human-AI collaboration. This document teaches you how to read, interpret, and work with SAGE specs.

## What is SAGE?

SAGE is a specification language that scales from natural language to formal verification. Users write specs at their comfort level, and you help them:
- Understand what the spec means
- Generate implementation code
- Suggest improvements or formalization
- Identify missing requirements
- Write tests from specifications

## Core Philosophy

> "Start informal. Formalize incrementally. SAGE grows with your needs."

- **Natural language is valid** — Quoted strings are real specs, not just comments
- **Formality is optional** — Users choose their level; don't force structure
- **Decisions matter** — `!!` marks implementation choices worth tracking
- **AI is a partner** — You help refine specs, not just consume them

---

## Formality Levels

### Level 0: Natural Language
Pure prose. Quick ideas, early exploration.

```sage
"Build a user authentication system"
"Users can register with email and password"
"Sessions expire after 24 hours"
!! "Use bcrypt for password hashing"
```

**Your role**: Extract requirements, suggest structure if asked, generate reasonable implementation.

### Level 1: Structured
Types, functions, contracts. Production-ready specs.

```sage
@mod user_auth

@type User = {
  email: Str,
  password_hash: Str,
  created_at: Time
}

@fn register(email: Str, password: Str) -> Result<User>
@req email.is_valid() && password.len() >= 8
@ens "User is created with hashed password"
```

**Your role**: Generate type-safe code, validate contracts, suggest missing cases.

### Level 2: Formal
Specifications, invariants, refinements. Critical systems.

```sage
@spec PaymentSystem
@state
  accounts: Map<AccountId, Balance>
@invariant ∀ a ∈ accounts: a.balance >= 0
@invariant ∑ accounts.values() = TOTAL_MONEY

@refine PaymentSystem as DistributedPayment
@decision "Use 2-phase commit" !!
@preserves ✓ "Money conservation"
```

**Your role**: Verify refinements preserve invariants, track design decisions, suggest verification approaches.

---

## Syntax Reference

### Declarations

| Syntax | Meaning |
|--------|---------|
| `@mod name` | Module declaration |
| `@type Name = { field: Type, ... }` | Record type definition |
| `@fn name(params) -> ReturnType` | Function signature |
| `@op name(params) -> ReturnType` | Operation (in specs) |
| `@spec Name` | Specification block |
| `@refine Parent as Child` | Refinement relationship |
| `@impl SpecName` | Implementation block |

### Contracts

| Syntax | Meaning |
|--------|---------|
| `@req condition` | Precondition (must be true before) |
| `@ens condition` | Postcondition (guaranteed after) |
| `@invariant expr` | Must always hold |
| `@property "desc"` | Named property to maintain |

### Refinement

| Syntax | Meaning |
|--------|---------|
| `@decision "text" !!` | Design decision (important) |
| `@preserves ✓ "property"` | Verified preservation |
| `@maps "description"` | How abstract maps to concrete |
| `[alternative]` | Marks alternative design |

### Control Flow (in function bodies)

```sage
let x = expression        # binding
if condition => result    # conditional
  else => other           # else branch
ret value                 # return
```

### Special Markers

| Syntax | Meaning |
|--------|---------|
| `"text"` | Natural language (spec or description) |
| `!! "text"` | Implementation decision |
| `!!let x = ...` | Decision-marked binding |
| `---` | Section separator |
| `# comment` | Line comment (not part of spec) |

### Math Symbols

| Symbol | Meaning |
|--------|---------|
| `∀` | For all (universal quantifier) |
| `∃` | There exists (existential quantifier) |
| `∈` | Element of (set membership) |
| `⟹` | Implies (logical implication) |
| `∑` | Sum (summation) |
| `'` | Prime (post-state, e.g., `x'` = x after operation) |
| `✓` | Checkmark (verified) |

### Types

Built-in types: `Str`, `Int`, `Bool`, `Time`, `Date`, `Money`, `()`

Generic types: `Result<T>`, `Option<T>`, `Set<T>`, `Map<K, V>`, `List<T>`

---

## How to Interpret SAGE Specs

### 1. Understand Intent Before Implementation

When you see a SAGE spec, first understand **what** it's trying to achieve:

```sage
@fn transfer(from: Account, to: Account, amount: Money) -> Result<()>
@req amount > 0
@req from.balance >= amount
@ens from.balance' = from.balance - amount
@ens to.balance' = to.balance + amount
```

**Interpretation**: "Transfer must move exactly `amount` from one account to another. It can only happen if there's sufficient balance. The total money in the system is preserved."

### 2. Respect Decision Markers

`!!` marks deliberate implementation choices. Don't silently change them:

```sage
!! "Use PostgreSQL with serializable isolation"
!! "Rate limit: 5 attempts per IP per minute"
```

If you think a decision should change, **ask first** and explain trade-offs.

### 3. Natural Language is Binding

Quoted strings are requirements, not suggestions:

```sage
"Passwords must never be logged"
"All API calls must be idempotent"
```

Treat these as seriously as formal constraints.

### 4. Inferred Annotations

When you notice implicit requirements, you can suggest them:

```sage
@inferred_req amount > 0 ← "From the validation check on line 5"
@inferred_ens "Database updated" ← "From db.save() call"
@inferred_effect "External API call" ← "From stripe.charge()"
```

Use `←` to explain your reasoning.

### 5. Refinement Chains

Refinements add detail while preserving parent properties:

```sage
@spec Abstract
@invariant "Property A"

@refine Abstract as Concrete
@preserves ✓ "Property A"  # Must still hold
@decision "Implementation detail" !!
```

Always verify that refinements don't break parent invariants.

---

## Working with Users

### When given a spec, you can:

1. **Explain it**: Describe what the spec means in plain language
2. **Implement it**: Generate code that satisfies the spec
3. **Test it**: Write tests that verify the contracts
4. **Improve it**: Suggest missing edge cases or formalizations
5. **Refine it**: Help add structure to natural language specs

### When generating code:

- Honor all `@req` preconditions with validation
- Ensure all `@ens` postconditions are satisfied
- Respect `!!` decision markers
- Preserve `@invariant` properties
- Handle error cases implied by `Result<T>` returns

### When suggesting improvements:

Ask before adding formality:
> "I notice you're checking `amount > 0`. Would you like me to add `@req amount > 0` to make this explicit?"

Explain trade-offs:
> "You could use `@invariant` here for stronger guarantees, but it would require..."

### When specs are ambiguous:

Ask clarifying questions:
> "The spec says 'sessions expire after 24 hours'. Should this be:
> 1. Exactly 24 hours from creation?
> 2. 24 hours of inactivity?
> 3. End of day + 24 hours?"

---

## Example Interactions

### User provides Level 0 spec:
```sage
"Build a rate limiter"
"Max 100 requests per minute per user"
!! "Use Redis"
```

**You might respond**:
"I'll implement a rate limiter with these characteristics:
- 100 requests/minute/user limit
- Redis backend (as specified)
- Sliding window algorithm (common choice)

Want me to also add `@type` definitions and `@fn` signatures before generating code?"

### User provides Level 1 spec:
```sage
@fn login(email: Str, password: Str) -> Result<Session>
@req email.is_valid()
@ens "Session created with 24h expiry"
```

**You generate**:
```typescript
async function login(email: string, password: string): Promise<Result<Session>> {
  // @req email.is_valid()
  if (!isValidEmail(email)) {
    return Err("Invalid email format");
  }
  
  // ... authentication logic ...
  
  // @ens "Session created with 24h expiry"
  const session = {
    id: generateToken(),
    userId: user.id,
    expiresAt: Date.now() + 24 * 60 * 60 * 1000
  };
  
  return Ok(session);
}
```

### User asks for refinement help:
"This function is getting complex. Should I use refinement?"

**You might respond**:
"Refinement is useful when:
- You want to track **why** you made certain choices
- The system might evolve (track alternatives)
- Multiple people need to understand the design

For a simple function, extracting helpers might be enough. But if this is a critical payment flow, refinement documents your reasoning for audits."

---

## Remember

1. **SAGE is flexible** — Don't force formality; meet users where they are
2. **Decisions are important** — `!!` marks things worth preserving
3. **Natural language counts** — Quoted strings are real requirements
4. **You're a partner** — Help improve specs, don't just execute them
5. **Ask when unsure** — Ambiguity is better resolved than assumed

When in doubt, explain what you understood and ask if it's correct.
