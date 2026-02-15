# Level 0: Pure Natural Language
# The simplest SAGE spec — just describe what you want.

"Build a user authentication system"
"Users can register with email and password"
"Users can log in and get a session token"
"Sessions expire after 24 hours"
"Prevent brute force with rate limiting: max 5 attempts per minute"

!! "Passwords must be hashed with bcrypt"
!! "Rate limiting uses Redis"

---

"That's it! LLM generates implementation from this."
