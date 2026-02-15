# SAGE Design Document (Original)

# ============ DESIGN PHILOSOPHY ============
"SAGE works at multiple levels of formality"

Level 0: Natural language only (quickest, AI-friendly)
Level 1: Structured specs (types + contracts, no refinement)
Level 2: Explicit refinement (when precision matters)
Level 3: Full formal verification (mission-critical systems)

"Users choose their level. SAGE scales with needs."

# ============ LEVEL 0: PURE NATURAL ============

"Build a user authentication system"
"Users can register with email and password"
"Users can log in and get a session token"
"Sessions expire after 24 hours"
"Prevent brute force with rate limiting: max 5 attempts per minute"

!! "Passwords must be hashed with bcrypt"
!! "Rate limiting uses Redis"

---

"That's it! LLM generates implementation from this."
"No refinement needed for simple cases."

# ============ LEVEL 1: STRUCTURED (No Refinement) ============

@mod user_auth
"A secure user authentication system"

@type User = {
  email: Str,
  password_hash: Str,
  created_at: Time
}

@type Session = {
  id: Str,
  user_email: Str,
  expires: Time
}

@fn register(email: Str, password: Str) -> Result<User>
"Create a new user account"
@req email.is_valid() && password.len() >= 8
@ens "User is created with hashed password"

"Check if user already exists"
let existing = db.find_by_email(email)
if existing.is_some() => ret Err("Email already registered")

"Hash password with bcrypt"
!!let hash = crypto.bcrypt_hash(password, cost: 12)

"Save user to database"
let user = {email: email, password_hash: hash, created_at: time.now()}
db.save_user(user)
ret Ok(user)

@fn login(email: Str, password: Str, ip: Str) -> Result<Session>
"Authenticate user and create session"
@req "Email and password must be provided"

"Check rate limit"
!!if attempts(ip) >= 5 => ret Err("Too many attempts")

"Find user and verify password"
let user = db.find_by_email(email)?
if !crypto.bcrypt_verify(password, user.password_hash) => ret Err("Invalid credentials")

"Create session token"
let session = {
  id: crypto.random_token(32),
  user_email: email,
  expires: time.now() + 24.hours()
}
db.save_session(session)
ret Ok(session)

---

"This is enough for most projects."
"Types + contracts + natural language = good spec"
"LLM generates working code from this"

# ============ LEVEL 2: OPTIONAL REFINEMENT ============

"Refinement is opt-in. Add it only where needed:"
"- Critical security properties"
"- Complex business logic"
"- System evolution tracking"
"- Team knowledge capture"

@spec UserAuth
"High-level: what the system should do"
@property "No duplicate emails"
@property "Sessions belong to valid users"
@property "Passwords never stored in plaintext"

"Most teams stop here. That's fine!"

---

"But if you want to track design evolution:"

@refine UserAuth
"We decided to use bcrypt with cost 12" !!
"We decided rate limiting with Redis"
"Alternative considered: JWT tokens (rejected - need revocation)"

@impl
... implementation code ...

---

"Or go deeper when needed:"

@spec UserAuth
@state
  users: Set<User>
  sessions: Set<Session>
@invariant ∀ s ∈ sessions: ∃ u ∈ users: s.user_email = u.email

@refine UserAuth as SecureAuth
@decision "bcrypt for password hashing" !!
@state
  users: Set<{email: Str, password_hash: Str, ...}>
@preserves "All parent invariants"

@impl SecureAuth
... actual code ...

# ============ PRACTICAL EXAMPLES ============

# Example 1: Quick prototype - Level 0

"Build a todo app"
"Users have lists of tasks"
"Tasks can be created, completed, deleted"
"Tasks have title, description, due date"

!! "Use PostgreSQL for storage"
!! "Use REST API with JSON"

---

"Done. LLM builds it."

# Example 2: Production app - Level 1

@mod todo_service

@type Task = {
  id: Int,
  user_id: Int,
  title: Str,
  description: Str,
  due_date: Date,
  completed: Bool
}

@fn create_task(user_id: Int, title: Str, desc: Str, due: Date) -> Result<Task>
@req title.len() > 0 && title.len() < 200
@req due >= today()

"Validate user exists"
let user = db.find_user(user_id)?

"Create the task"
let task = {
  id: db.next_id(),
  user_id: user_id,
  title: title,
  description: desc,
  due_date: due,
  completed: false
}
db.insert_task(task)
ret Ok(task)

@fn complete_task(task_id: Int, user_id: Int) -> Result<()>
"Mark a task as complete"
@req "User owns the task"

let task = db.find_task(task_id)?

"Verify ownership"
if task.user_id != user_id => ret Err("Not authorized")

"Mark complete"
db.update(task_id, {completed: true})
ret Ok(())

---

"Good for 90% of applications"

# Example 3: Mission-critical - Level 2 (Optional Refinement)

"Payment processing - need formal verification"

@spec PaymentProcessor
"Process payments securely with guarantees"
@state
  accounts: Map<AccountId, Balance>
  transactions: Set<Transaction>
@invariant "Money is conserved"
  ∑ accounts.values() = TOTAL_MONEY
@invariant "No double-spending"
  ∀ t1,t2 ∈ transactions: t1.id = t2.id ⟹ t1 = t2

@op transfer(from: AccountId, to: AccountId, amount: Money) -> Result<()>
@req accounts[from] >= amount
@ens accounts'[from] = accounts[from] - amount
@ens accounts'[to] = accounts[to] + amount
@ens |transactions'| = |transactions| + 1

@refine PaymentProcessor as DistributedPayment
@decision "Use 2-phase commit for distributed transactions" !!
@decision "Idempotency via transaction IDs"
@maps "Concrete distributed state maps to abstract state"
  accounts_abstract = merge(node1.accounts, node2.accounts, ...)
@preserves
  ✓ "Money conservation: sum across all nodes"
  ✓ "No double-spending: transaction IDs are unique globally"

@impl DistributedPayment
"Actual 2PC implementation"
...

---

"Refinement only where you need the rigor"

# ============ PROGRESSIVE ENHANCEMENT ============

"SAGE lets you START SIMPLE and ADD FORMALITY as needed"

# Week 1: Prototype
"Build a payment system"
"Handle transfers between accounts"

# Week 2: Add structure
@fn transfer(from: AccountId, to: AccountId, amount: Money)
@req amount > 0
...

# Week 3: Add invariants (discovered a bug!)
@invariant "Balance never negative"
  ∀ a ∈ accounts: a.balance >= 0

# Month 2: Going to production, add refinement
@spec PaymentSystem
...

@refine PaymentSystem as ProductionPayment
@decision "Use PostgreSQL with serializable isolation" !!
@preserves "All invariants"

# Month 6: Scaling, explore alternatives
@refine PaymentSystem as ShardedPayment [alternative]
@decision "Shard by account ID for horizontal scale"
@compare_with ProductionPayment
  advantages: "Better throughput"
  disadvantages: "Cross-shard transfers complex"

---

"You control how formal you want to be"

# ============ SMART DEFAULTS ============

"SAGE helps without forcing formality"

@fn process_payment(amount: Money) -> Result<()>
"Process a customer payment"

"Validate amount"
if amount <= 0 => ret Err("Amount must be positive")

"Charge the customer"
let charge_result = stripe.charge(customer_id, amount)

"Record in database"
db.record_payment({
  customer_id: customer_id,
  amount: amount,
  timestamp: now()
})
ret Ok(())

---

"SAGE infers implicit specs:"

@fn process_payment(amount: Money) -> Result<()>
@inferred_req amount > 0           ← "From the validation check"
@inferred_ens "Payment recorded"   ← "From db.record_payment"
@inferred_effect "External API call" ← "From stripe.charge"

---

"You didn't write specs, but SAGE understands them"
"LLM can generate tests, docs, and verification from this"

# ============ WHEN TO USE REFINEMENT ============

Use refinement when:
✓ System is critical (payments, health, safety)
✓ Design evolved and you want to track why
✓ Team needs to understand design decisions
✓ Multiple implementation strategies possible
✓ Verification required (regulations, audit)
✓ Onboarding new engineers (refinement = docs)

Skip refinement when:
✓ Rapid prototyping
✓ Throwaway code
✓ Obvious, simple logic
✓ Well-understood patterns
✓ Low-risk systems

# ============ TOOL-ASSISTED WORKFLOW ============

# Scenario: Engineer writes natural spec

"Build an authentication system with email/password"
"Hash passwords with bcrypt"
"Rate limit login attempts"

# SAGE tool suggests:

> I notice you mentioned rate limiting. Would you like to:
>
> [1] Keep it informal (I'll implement sensible defaults)
> [2] Add structured spec (define exact limits)
> [3] Use refinement (explore multiple strategies)
>
> Recommendation: [2] for production systems

# User picks [2]:

@fn login(email: Str, password: Str, ip: Str) -> Result<Session>
@req "Rate limit: max 5 attempts per IP per minute"
...

# Tool generates implementation

> Generated: Redis-based rate limiter
> Tests: 3 scenarios covered
>
> Want to explore alternatives? Try:
> @refine login as ... [alternative]

---

"Tool helps, but never forces refinement"

# ============ COMPARISON: SAME SYSTEM, DIFFERENT LEVELS ============

# Level 0: Pure Natural (50 tokens)
"Auth system: register, login, sessions. Bcrypt passwords. Rate limit 5/min."

# Level 1: Structured (200 tokens)
@fn register(email, pwd) -> Result<User>
@req email.valid()
!!let hash = bcrypt(pwd)
...

# Level 2: With Refinement (800 tokens)
@spec Auth
...
@refine Auth as SecureAuth
@decision "bcrypt cost 12"
@preserves invariants
@impl
...

---

"Choose your level. SAGE works at all of them."

# ============ MIGRATION PATH ============

"Start informal, formalize incrementally"

# Day 1
"Build todo app"

# Day 30
@mod todo_app
@fn create_task(...)

# Day 90 (found bugs, need clarity)
@fn create_task(...)
@req title.len() > 0
@invariant "Tasks belong to users"

# Day 180 (going enterprise)
@spec TodoSystem
@refine TodoSystem as MultiTenantTodo
@decision "Tenant isolation via row-level security"

---

"Formality grows with needs"

# ============ LLM INTERACTION ============

# Informal → LLM generates structure

User: "Build user auth"

LLM: "I'll create:
- @mod user_auth
- @fn register(email, password)
- @fn login(email, password)
Using bcrypt and PostgreSQL. Sound good?"

User: "Yes"

LLM: [generates Level 1 spec + implementation]

---

# Structured → LLM suggests refinement

User: "This login function is getting complex"

LLM: "I notice multiple concerns:
- Password verification
- Rate limiting
- Session creation

Would you like me to:
[1] Extract helper functions (simpler)
[2] Create a refinement structure (formal)

I recommend [1] unless you need to track design decisions."

---

# User asks for refinement

User: "Actually, let's use refinement. We might change session strategy later."

LLM: "Creating refinement structure:

@spec SessionManagement
'High-level session concept'

@refine SessionManagement as ServerSessions
@decision 'Server-side sessions in PostgreSQL'
@alternative 'Could use JWT tokens instead'

Want me to also create the JWT alternative for comparison?"

# ============ FINAL PRINCIPLE ============

"Refinement is POWER, not BURDEN"
"Use it when it helps. Skip it when it doesn't."
"SAGE works beautifully at all formality levels."
"The choice is yours. Always."
