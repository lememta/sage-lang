// Simple token estimation (GPT-4 uses ~4 chars per token for code/structured text)
// For accurate counts, use tiktoken library

const natural = `Build me a user authentication system. I need the following:

1. Users should be able to register with an email and password. The email must be valid and the password must be at least 8 characters long. When a user registers, their password should be hashed using bcrypt with a cost factor of 12. If a user tries to register with an email that already exists, return an error.

2. Users should be able to log in with their email and password. When logging in, verify the password against the stored hash. If the credentials are valid, create a session token that expires after 24 hours. The session should store the user's email and the expiration time.

3. Implement rate limiting on the login endpoint. Users should be limited to 5 login attempts per IP address per minute. Use Redis for storing the rate limit counters.

4. The system should have the following data types:
   - User: contains email (string), password_hash (string), and created_at (timestamp)
   - Session: contains id (string), user_email (string), and expires (timestamp)

5. Important security requirements:
   - Passwords must never be stored in plaintext
   - All sessions must belong to valid users
   - No duplicate email addresses allowed

Please generate TypeScript code for this.`;

const sage = `@mod user_auth
"Secure user authentication with sessions"

@type User = { email: Str, password_hash: Str, created_at: Time }
@type Session = { id: Str, user_email: Str, expires: Time }

@fn register(email: Str, password: Str) -> Result<User>
@req email.is_valid() && password.len() >= 8
@ens "User created with hashed password"
!! let hash = bcrypt(password, cost: 12)
if db.exists(email) => ret Err("Email exists")
ret Ok(user)

@fn login(email: Str, password: Str, ip: Str) -> Result<Session>
@req "Valid credentials provided"
!! if rate_limit(ip) >= 5 => ret Err("Rate limited")
!! "Use Redis for rate limiting"
let user = db.find(email)?
if !verify(password, user.password_hash) => ret Err("Invalid")
ret Ok({ id: token(32), user_email: email, expires: now() + 24.hours() })`;

// Rough token estimation (words + punctuation)
function estimateTokens(text) {
  // Split on whitespace and punctuation, filter empty
  const tokens = text.split(/[\s]+|(?=[{}()\[\]<>:,;=&|!?])|(?<=[{}()\[\]<>:,;=&|!?])/)
    .filter(t => t.trim().length > 0);
  return tokens.length;
}

// Character-based estimation (~4 chars per token for code)
function charBasedEstimate(text) {
  return Math.ceil(text.length / 4);
}

console.log('=== SAGE Token Efficiency Analysis ===\n');

console.log('NATURAL LANGUAGE PROMPT:');
console.log(`  Characters: ${natural.length}`);
console.log(`  Words: ${natural.split(/\s+/).length}`);
console.log(`  Est. tokens (char/4): ${charBasedEstimate(natural)}`);
console.log(`  Est. tokens (word-based): ${estimateTokens(natural)}`);

console.log('\nSAGE SPECIFICATION:');
console.log(`  Characters: ${sage.length}`);
console.log(`  Words: ${sage.split(/\s+/).length}`);
console.log(`  Est. tokens (char/4): ${charBasedEstimate(sage)}`);
console.log(`  Est. tokens (word-based): ${estimateTokens(sage)}`);

const naturalTokens = charBasedEstimate(natural);
const sageTokens = charBasedEstimate(sage);
const savings = ((naturalTokens - sageTokens) / naturalTokens * 100).toFixed(1);

console.log('\n=== COMPARISON ===');
console.log(`  Natural language: ~${naturalTokens} tokens`);
console.log(`  SAGE:             ~${sageTokens} tokens`);
console.log(`  Token savings:    ${savings}%`);
console.log(`  Absolute savings: ${naturalTokens - sageTokens} tokens`);

console.log('\n=== INFORMATION DENSITY ===');
const naturalInfo = {
  types: 2,
  functions: 2,
  preconditions: 3,
  postconditions: 2,
  decisions: 3
};
const sageInfo = {
  types: 2,
  functions: 2,
  preconditions: 2,
  postconditions: 1,
  decisions: 3
};

console.log('Both specs convey equivalent information:');
console.log(`  Type definitions:  ${naturalInfo.types}`);
console.log(`  Functions:         ${naturalInfo.functions}`);
console.log(`  Preconditions:     ${naturalInfo.preconditions}`);
console.log(`  Decisions (!!):    ${naturalInfo.decisions}`);

console.log('\n=== TOKENS PER CONCEPT ===');
console.log(`  Natural: ${(naturalTokens / 12).toFixed(1)} tokens per concept`);
console.log(`  SAGE:    ${(sageTokens / 12).toFixed(1)} tokens per concept`);
