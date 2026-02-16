# SAGE Tutorial: From Idea to Implementation

Welcome! This tutorial will teach you how to use SAGE to write specifications that help AI assistants generate better code, faster.

**What you'll learn:**
- Write specs at your comfort level (natural language → formal)
- Use SAGE with ChatGPT, Claude, or any LLM
- Get better code with fewer back-and-forth iterations

**Time:** 15-20 minutes

---

## What is SAGE?

SAGE (Semi-formal AI-Guided Engineering) is a simple language for writing specifications. Instead of describing what you want in paragraphs of text, you use a structured format that:

- **Saves tokens** (38% fewer than natural language)
- **Reduces ambiguity** (LLMs understand exactly what you need)
- **Produces better code** (contracts become validation, types become interfaces)

The best part? **You choose your level of formality.** Start with plain English, add structure when you need it.

---

## Part 1: Your First SAGE Spec (5 minutes)

Let's build a todo app. We'll start simple.

### Level 0: Just Write What You Want

Create a file called `todo.sage`:

```sage
"Build a todo app"
"Users can create tasks with a title"
"Users can mark tasks as complete"
"Users can delete tasks"

!! "Use TypeScript"
!! "Store data in localStorage"
```

That's it! This is valid SAGE.

**What's happening here:**
- `"quoted text"` = requirements (the LLM will implement these)
- `!! "text"` = implementation decisions (specific tech choices)

### Try It With an LLM

Copy this prompt to ChatGPT or Claude:

```
I'm using SAGE specification format. Please implement this spec:

"Build a todo app"
"Users can create tasks with a title"
"Users can mark tasks as complete"
"Users can delete tasks"

!! "Use TypeScript"
!! "Store data in localStorage"

Generate the code following SAGE conventions:
- Implement all quoted requirements
- Use the !! marked technology choices
```

You'll get working code that follows your spec!

---

## Part 2: Adding Structure (5 minutes)

Your todo app is growing. Let's add some structure.

### Level 1: Types and Functions

Update `todo.sage`:

```sage
@mod todo_app
"A simple todo application"

@type Task = {
  id: Str,
  title: Str,
  completed: Bool,
  created_at: Time
}

@fn create_task(title: Str) -> Task
"Create a new task"
@req title.len() > 0
@req title.len() <= 200
@ens "Task created with completed = false"
@ens "Task has unique id"

@fn complete_task(id: Str) -> Result<Task>
"Mark a task as complete"
@req "Task with id must exist"
@ens task.completed = true

@fn delete_task(id: Str) -> Result<()>
"Remove a task"
@req "Task with id must exist"
@ens "Task no longer in storage"

!! "Use TypeScript"
!! "Use localStorage"
!! "Use UUID for task ids"
```

**New concepts:**
- `@mod name` = module declaration (names your component)
- `@type Name = {...}` = defines a data structure
- `@fn name(...) -> Type` = function signature
- `@req condition` = precondition (must be true before calling)
- `@ens condition` = postcondition (guaranteed after calling)

### What the LLM Will Generate

From this spec, an LLM will create:

```typescript
// Types
interface Task {
  id: string;
  title: string;
  completed: boolean;
  created_at: Date;
}

// Functions with validation
function createTask(title: string): Task {
  // @req title.len() > 0
  if (title.length === 0) {
    throw new Error("Title cannot be empty");
  }
  // @req title.len() <= 200
  if (title.length > 200) {
    throw new Error("Title too long");
  }
  
  // @ens Task has unique id (!! Use UUID)
  const task: Task = {
    id: crypto.randomUUID(),
    title,
    completed: false,  // @ens completed = false
    created_at: new Date()
  };
  
  // ... save to localStorage
  return task;
}
```

**Notice:** Every `@req` becomes validation. Every `@ens` is implemented. Every `!!` decision is followed.

---

## Part 3: Real-World Example (5 minutes)

Let's build something more realistic: a user authentication system.

### The Spec

Create `auth.sage`:

```sage
@mod auth
"User authentication with sessions"

# ========== Types ==========

@type User = {
  id: Str,
  email: Str,
  password_hash: Str,
  created_at: Time
}

@type Session = {
  token: Str,
  user_id: Str,
  expires_at: Time
}

# ========== Registration ==========

@fn register(email: Str, password: Str) -> Result<User>
"Create a new user account"

@req email.is_valid_email()
@req password.len() >= 8
@req "Password has at least one number"
@req "Password has at least one uppercase letter"

@ens "User saved to database"
@ens "Password is hashed, never stored in plaintext"

!! "Use bcrypt with cost factor 12"
!! "Check for existing email before creating"

# ========== Login ==========

@fn login(email: Str, password: Str) -> Result<Session>
"Authenticate and create a session"

@req "User with email must exist"
@req "Password must match stored hash"

@ens "Session token is cryptographically random"
@ens "Session expires in 24 hours"

!! "Use crypto.randomBytes(32) for token"
!! "Store session in Redis with TTL"

# ========== Logout ==========

@fn logout(token: Str) -> Result<()>
"End a session"

@req "Session must exist"
@ens "Session is deleted"

---

# Security Requirements (apply to all functions)

"All passwords must be hashed before storage"
"Rate limit login attempts: 5 per minute per IP"
"Log all authentication events"

!! "Use Redis for rate limiting"
!! "Use PostgreSQL for users"
```

### Using This Spec

**Prompt for implementation:**
```
Using SAGE format. Implement this authentication system:

[paste the spec]

Generate:
1. TypeScript interfaces for the types
2. Functions with full validation
3. Respect all !! decisions
```

**Prompt for tests:**
```
Generate unit tests for this SAGE spec:

[paste the spec]

Create tests for:
- Each @req precondition (test that violations are rejected)
- Each @ens postcondition (test that guarantees hold)
- Edge cases
```

**Prompt for documentation:**
```
Generate API documentation from this SAGE spec:

[paste the spec]

Include:
- Function signatures
- Parameter requirements
- Return values
- Error conditions
```

---

## Part 4: Advanced Features (Optional)

When you need more rigor—financial systems, healthcare, anything critical.

### Invariants

Things that must **always** be true:

```sage
@spec BankAccount
@state balance: Money

@invariant balance >= 0
"Balance can never go negative"

@op withdraw(amount: Money) -> Result<()>
@req amount > 0
@req balance >= amount
@ens balance' = balance - amount
```

The `'` (prime) notation means "after the operation". So `balance'` is the new balance.

### Refinement

Track how your design evolves:

```sage
@spec PaymentSystem
@invariant "Money is conserved"

@refine PaymentSystem as DistributedPayment
@decision "Use 2-phase commit for distributed transactions" !!
@decision "Shard by account ID" !!

@preserves
  ✓ "Money conservation"
  ✓ "No double-spending"
```

This documents **why** you made certain choices—invaluable for team handoffs and audits.

---

## Part 5: Tips & Best Practices

### 1. Start Simple

```sage
# Good: Start here
"Build a blog"
"Users can write posts"
"Posts have titles and content"

# Add structure later when needed
@type Post = { ... }
```

### 2. Mark All Tech Decisions

```sage
# Good: Explicit
!! "Use PostgreSQL"
!! "Use Redis for caching"
!! "Use bcrypt for passwords"

# Bad: Hidden in prose
"Store users in the database and cache with Redis"
```

### 3. Be Specific in Requirements

```sage
# Good: Testable
@req password.len() >= 8
@req email.contains("@")

# Less good: Vague
@req "Password must be secure"
@req "Email must be valid"
```

### 4. Use @ens for Guarantees

```sage
# Good: Clear contract
@fn createUser(email: Str) -> User
@ens "User.id is a valid UUID"
@ens "User.created_at is current time"

# Bad: Hope LLM figures it out
@fn createUser(email: Str) -> User
"Creates a user somehow"
```

### 5. Group Related Specs

```sage
# ========== User Management ==========
@fn createUser(...) -> User
@fn deleteUser(...) -> ()

# ========== Authentication ==========
@fn login(...) -> Session
@fn logout(...) -> ()

---  # Section separator

# Implementation Notes
!! "Deployment uses Docker"
```

---

## Quick Reference Card

```
SAGE SYNTAX CHEAT SHEET

Comments:       # this is a comment
Natural text:   "requirement or description"
Decision:       !! "implementation choice"
Separator:      ---

Module:         @mod module_name
Type:           @type Name = { field: Type, ... }
Function:       @fn name(param: Type) -> ReturnType
Precondition:   @req condition
Postcondition:  @ens condition

Spec:           @spec Name
State:          @state field: Type
Invariant:      @invariant condition
Operation:      @op name(params) -> ReturnType

Refinement:     @refine Parent as Child
Decision:       @decision "reason" !!
Preserves:      @preserves ✓ "property"

Control flow:
  let x = value
  if condition => result
  ret value

Math symbols:
  ∀ (for all)   ∃ (exists)   ∈ (element of)
  ⟹ (implies)   ∑ (sum)      ' (post-state)
```

---

## What's Next?

1. **Install VS Code extension** for syntax highlighting:
   ```bash
   cd packages/vscode
   npx @vscode/vsce package --no-dependencies
   code --install-extension sage-vscode-0.1.0.vsix
   ```

2. **Read more examples** in the `examples/` folder

3. **Try the parser** programmatically:
   ```typescript
   import { parse } from '@sage-lang/parser';
   const ast = parse(sageCode);
   ```

4. **Add AGENT.md to your LLM** for better SAGE understanding

---

## Example Prompts for LLMs

### Generate Implementation
```
Implement this SAGE spec in [language]:
[your spec]

Requirements:
- Validate all @req preconditions
- Ensure all @ens postconditions
- Follow all !! decisions
```

### Generate Tests
```
Write tests for this SAGE spec:
[your spec]

Cover:
- Happy paths
- @req violations (should fail/throw)
- Edge cases
```

### Review Code Against Spec
```
Does this code satisfy this SAGE spec?

Spec:
[your spec]

Code:
[your code]

Check each @req, @ens, and !! decision.
```

### Suggest Improvements
```
Review this SAGE spec and suggest improvements:
[your spec]

Look for:
- Missing error cases
- Implicit requirements that should be explicit
- Opportunities for @invariant
```

---

Happy spec writing! 🌿

Remember: **Start simple, add structure when you need it, let SAGE grow with your project.**
