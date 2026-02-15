# Inferred Annotations (tool-generated)

@fn process_payment(amount: Money) -> Result<()>
"Process a customer payment"

"Validate amount"
if amount <= 0 => ret Err("Amount must be positive")

"Charge the customer"
let charge_result = stripe.charge(customer_id, amount)

"Record in database"
ret Ok(())

---

"SAGE infers implicit specs:"

@inferred_req amount > 0 ← "From the validation check"
@inferred_ens "Payment recorded" ← "From db.record_payment"
@inferred_effect "External API call" ← "From stripe.charge"
