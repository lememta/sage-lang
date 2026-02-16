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
   ./scripts/setup-vscode-lsp.sh
   ```

2. **Read more examples** in the `examples/` folder

3. **Try the compiler** directly:
   ```bash
   .lake/build/bin/sage your-spec.sage
   ```

4. **Add AGENT.md to your LLM** for better SAGE understanding

---

## Using SAGE with Claude Code

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) is Anthropic's agentic coding tool that lives in your terminal. It can read files, write code, and execute commands. SAGE and Claude Code work beautifully together.

### Setup: Add SAGE Understanding

First, add the SAGE `AGENT.md` to your project so Claude Code understands the format:

```bash
# Copy AGENT.md to your project root
cp path/to/sage-lang/AGENT.md ./AGENT.md
```

Or create a `CLAUDE.md` in your project with SAGE instructions:

```markdown
# CLAUDE.md

## SAGE Specifications

This project uses SAGE (.sage files) for specifications. When you see SAGE:

- `"quoted text"` = requirements to implement
- `!! "text"` = implementation decisions (don't change without asking)
- `@req` = preconditions (validate these)
- `@ens` = postconditions (ensure these)
- `@type` = type definitions
- `@fn` = function signatures

Always implement all requirements and respect !! decisions.
```

### Workflow 1: Generate from Spec

Write your spec first, then ask Claude Code to implement it:

```bash
# Create your spec
cat > auth.sage << 'EOF'
@mod auth

@type User = { id: Str, email: Str, password_hash: Str }

@fn register(email: Str, password: Str) -> Result<User>
@req email.contains("@")
@req password.len() >= 8
@ens "Password is hashed with bcrypt"

!! "Use bcrypt with cost 12"
!! "Store users in PostgreSQL"
EOF

# Ask Claude Code to implement
claude "Read auth.sage and implement it in TypeScript. Create src/auth.ts with all the functions. Validate all @req preconditions and follow the !! decisions."
```

### Workflow 2: Spec-Driven Development

Use Claude Code interactively for spec-driven development:

```bash
# Start Claude Code
claude

# Then in the session:
> Read auth.sage and explain what it specifies

> Implement the register function from auth.sage in TypeScript

> Now write unit tests that verify each @req and @ens

> The spec says !! "Use bcrypt with cost 12" - verify the implementation uses this
```

### Workflow 3: Review Code Against Spec

Have Claude Code verify implementations match specs:

```bash
claude "Compare src/auth.ts against auth.sage. Check:
1. Are all @req preconditions validated?
2. Are all @ens postconditions satisfied?
3. Are all !! decisions followed?
List any discrepancies."
```

### Workflow 4: Evolve Spec and Code Together

When requirements change, update the spec first:

```bash
# Add rate limiting to the spec
cat >> auth.sage << 'EOF'

@fn login(email: Str, password: Str, ip: Str) -> Result<Session>
@req "Rate limit: max 5 attempts per IP per minute"
!! "Use Redis for rate limiting"
EOF

# Ask Claude Code to update the implementation
claude "I've added a login function to auth.sage with rate limiting. Update src/auth.ts to implement it. Use the existing patterns from register."
```

### Pro Tips for Claude Code + SAGE

1. **Keep specs in the repo** — Claude Code reads files, so it can always reference the spec

2. **Use `!!` for non-negotiables** — Claude Code will respect these decisions:
   ```sage
   !! "Use PostgreSQL, not SQLite"
   !! "All dates in UTC"
   !! "Never log passwords"
   ```

3. **Ask for verification** — After generating code:
   ```
   > Verify src/auth.ts satisfies all contracts in auth.sage
   ```

4. **Iterate on the spec** — If Claude Code's output isn't right, improve the spec:
   ```
   > The register function doesn't check for duplicate emails. 
     Add this to auth.sage: @req "Email must not already exist"
     Then update the implementation.
   ```

5. **Generate tests from specs** — SAGE contracts map directly to tests:
   ```
   > Generate Jest tests for auth.sage. Each @req should have a test 
     that verifies violations are rejected.
   ```

### Example Session

```bash
$ claude

> Read payment.sage and summarize the key requirements

Looking at payment.sage:
- Payment type with id, amount, currency, status
- process_payment function requires amount > 0 and <= 10000
- Must use Stripe for processing (marked with !!)
- Must generate UUID for transaction IDs (marked with !!)
- Postcondition: payment recorded in database

> Implement this in TypeScript with proper error handling

Creating src/payment.ts...
[generates implementation]

> Does this implementation satisfy all the @ens postconditions?

Checking postconditions:
✓ "Payment is recorded in database" - Yes, line 45 calls db.insert()
✓ "Transaction ID is unique" - Yes, using crypto.randomUUID()

> Add a refund function to payment.sage, then implement it

Adding to payment.sage:
@fn refund(payment_id: Str) -> Result<Payment>
@req "Original payment must exist"
@req "Payment must be in Completed status"  
@ens "Payment status changed to Refunded"
!! "Call Stripe refund API"

Updating src/payment.ts with refund function...
```

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
