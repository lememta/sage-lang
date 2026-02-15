# Level 1: Structured Spec (types + contracts)

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
ret Ok(session)

---

"Types + contracts + natural language = good spec"
