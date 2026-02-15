---
name: sage-interpreter
description: Interpret SAGE specs (Semi-formal AI-Guided Engineering). Read specs at any formality level and generate implementations, tests, or improvements.
metadata:
  openclaw:
    emoji: "🌿"
    triggers:
      - "*.sage"
      - "sage spec"
      - "sage file"
---

# SAGE Interpreter Skill

Interpret and work with **SAGE** (Semi-formal AI-Guided Engineering) specification files.

## Quick Reference

### What is SAGE?

A spec language with 3 formality levels:
- **Level 0**: Natural language (`"Build a todo app"`)
- **Level 1**: Structured (`@type`, `@fn`, `@req`, `@ens`)
- **Level 2**: Formal (`@spec`, `@invariant`, `@refine`)

### Key Syntax

```
@mod name          Module declaration
@type Name = {}    Type definition
@fn name() -> T    Function signature
@req condition     Precondition
@ens condition     Postcondition
@spec Name         Specification block
@invariant expr    Invariant constraint
@refine A as B     Refinement
@decision "x" !!   Design decision
!! "text"          Implementation decision marker
"text"             Natural language requirement
---                Section separator
```

### Math Symbols

`∀` (forall), `∃` (exists), `∈` (element of), `⟹` (implies), `∑` (sum), `'` (post-state), `✓` (verified)

---

## When to Use This Skill

Activate when user:
- Shares a `.sage` file
- Asks about SAGE syntax
- Wants to generate code from a spec
- Wants to formalize requirements
- Asks to write tests from a spec

## Interpretation Rules

### 1. Natural Language is Binding

Quoted strings are requirements, not comments:
```sage
"All passwords must be hashed"  # ← This is a real requirement
```

### 2. Respect Decision Markers

`!!` marks deliberate choices. Don't change without asking:
```sage
!! "Use bcrypt with cost 12"  # ← User chose this deliberately
```

### 3. Contracts Are Guarantees

- `@req` = precondition (validate before execution)
- `@ens` = postcondition (must be true after)
- `@invariant` = always true (never violated)

### 4. Infer Missing Specs

When you notice implicit requirements:
```sage
@inferred_req amount > 0 ← "From validation on line 5"
```

Use `←` to explain your reasoning.

---

## Common Tasks

### Generate Implementation

Given:
```sage
@fn transfer(from: Account, to: Account, amount: Money) -> Result<()>
@req amount > 0
@req from.balance >= amount
@ens from.balance' = from.balance - amount
```

Generate code that:
1. Validates all `@req` preconditions
2. Implements the core logic
3. Ensures all `@ens` postconditions hold
4. Returns appropriate `Result` type

### Generate Tests

From the same spec, generate tests for:
- Happy path (valid transfer)
- `@req` violations (negative amount, insufficient balance)
- Edge cases (zero balance after, same account)

### Suggest Improvements

Look for:
- Missing error cases
- Implicit requirements that should be explicit
- Opportunities for `@invariant` constraints
- Natural language that could be formalized

### Help Refine

When specs evolve, help track decisions:
```sage
@refine SimplePayment as DistributedPayment
@decision "Sharding by account ID for scale" !!
@preserves ✓ "Money conservation"
```

---

## Response Patterns

### When explaining a spec:

```
This spec defines [what it does]:

**Types**: [list types and their purpose]
**Functions**: [list functions and contracts]
**Invariants**: [list what must always hold]
**Decisions**: [list !! marked choices]

Key requirements:
- [Natural language requirements]
- [Inferred requirements]
```

### When generating code:

```
Based on the spec, here's the implementation:

[code]

This satisfies:
- @req [condition]: [how it's validated]
- @ens [condition]: [how it's ensured]
- !! [decision]: [how it's implemented]
```

### When suggesting improvements:

```
I noticed some potential improvements:

1. [Observation] → Suggest: [improvement]
   Reason: [why]

2. [Observation] → Suggest: [improvement]
   Reason: [why]

Want me to apply any of these?
```

---

## Formality Guidance

Help users choose the right level:

| Situation | Recommended Level |
|-----------|------------------|
| Quick prototype | Level 0 (natural) |
| Production code | Level 1 (structured) |
| Critical systems | Level 2 (formal) |
| Exploring ideas | Level 0 → 1 |
| Found bugs | Add `@invariant` |
| Team handoff | Add `@decision` markers |

**Don't force formality.** If user is happy at Level 0, help them there.

---

## Examples

### Level 0 → Implementation

**Input:**
```sage
"Build a rate limiter"
"Max 100 requests per minute per user"
!! "Use sliding window"
```

**Response:**
"I'll implement a rate limiter with:
- 100 req/min/user limit
- Sliding window algorithm (as specified with !!)

[generates code]

Want me to also write the spec at Level 1 for documentation?"

### Level 1 → Tests

**Input:**
```sage
@fn validate_email(email: Str) -> Bool
@req email.len() > 0
@ens "Returns true iff email matches RFC 5322"
```

**Response:**
"Here are tests covering the spec:

```typescript
describe('validate_email', () => {
  // @req email.len() > 0
  it('rejects empty string', () => {...});
  
  // @ens RFC 5322 compliance
  it('accepts valid email', () => {...});
  it('rejects missing @', () => {...});
  it('rejects invalid domain', () => {...});
});
```"

### Level 2 → Verification

**Input:**
```sage
@spec Counter
@state count: Int
@invariant count >= 0

@op increment() -> ()
@ens count' = count + 1
```

**Response:**
"This spec defines a non-negative counter.

**Verification check:**
- `increment` preserves `count >= 0` ✓ (adding 1 to non-negative stays non-negative)

Note: There's no `decrement` operation. If you add one, you'll need:
```sage
@op decrement() -> Result<()>
@req count > 0  # Needed to preserve invariant
@ens count' = count - 1
```"

---

## Remember

1. **Spec intent > literal text** — Understand what they're trying to achieve
2. **Natural language counts** — `"text"` is a real requirement
3. **`!!` is sacred** — Don't change decisions without asking
4. **Meet users where they are** — Don't force formality
5. **Suggest, don't dictate** — Offer improvements, let them choose
