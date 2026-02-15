# Level 2: Formal Specification with Refinement

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
@preserves
  ✓ "Money conservation: sum across all nodes"
  ✓ "No double-spending: transaction IDs are unique globally"

@impl DistributedPayment
"Actual 2PC implementation"
...

---

@refine PaymentProcessor as ShardedPayment [alternative]
@decision "Shard by account ID for horizontal scale"
@compare_with DistributedPayment
  advantages: "Better throughput"
  disadvantages: "Cross-shard transfers complex"

---

"Refinement only where you need the rigor"
