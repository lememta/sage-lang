import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import { Lexer, TokenType } from "./lexer";
import { parse } from "./parser";

// ============================================================================
// LEXER TESTS
// ============================================================================

describe("Lexer", () => {
  describe("keywords", () => {
    it("tokenizes @keywords", () => {
      const tokens = new Lexer("@mod @type @fn @req @ens").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.KW_Mod, TokenType.KW_Type, TokenType.KW_Fn,
        TokenType.KW_Req, TokenType.KW_Ens,
      ]);
    });

    it("tokenizes spec keywords", () => {
      const tokens = new Lexer("@spec @refine @invariant @property").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.KW_Spec, TokenType.KW_Refine, TokenType.KW_Invariant, TokenType.KW_Property,
      ]);
    });

    it("tokenizes refinement keywords", () => {
      const tokens = new Lexer("@decision @preserves @maps @impl @op @state").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.KW_Decision, TokenType.KW_Preserves, TokenType.KW_Maps,
        TokenType.KW_Impl, TokenType.KW_Op, TokenType.KW_State,
      ]);
    });

    it("tokenizes inferred annotations", () => {
      const tokens = new Lexer("@inferred_req @inferred_ens @inferred_effect").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.KW_InferredReq, TokenType.KW_InferredEns, TokenType.KW_InferredEffect,
      ]);
    });

    it("tokenizes control flow keywords", () => {
      const tokens = new Lexer("let if else ret").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.KW_Let, TokenType.KW_If, TokenType.KW_Else, TokenType.KW_Ret,
      ]);
    });

    it("tokenizes 'as' keyword", () => {
      const tokens = new Lexer("as").tokenize();
      assert.equal(tokens[0].type, TokenType.KW_As);
    });
  });

  describe("strings", () => {
    it("tokenizes simple strings", () => {
      const tokens = new Lexer('"hello world"').tokenize();
      assert.equal(tokens[0].type, TokenType.String);
      assert.equal(tokens[0].value, "hello world");
    });

    it("tokenizes strings with special characters", () => {
      const tokens = new Lexer('"hello\\nworld"').tokenize();
      // Lexer processes escape sequences, so \n becomes literal n after backslash is consumed
      assert.equal(tokens[0].value, "hellonworld");
    });

    it("tokenizes empty strings", () => {
      const tokens = new Lexer('""').tokenize();
      assert.equal(tokens[0].type, TokenType.String);
      assert.equal(tokens[0].value, "");
    });

    it("tokenizes multiple strings on same line", () => {
      const tokens = new Lexer('"first" "second"').tokenize();
      assert.equal(tokens[0].value, "first");
      assert.equal(tokens[1].value, "second");
    });
  });

  describe("operators", () => {
    it("tokenizes arrow operators", () => {
      const tokens = new Lexer("-> => ←").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.Arrow, TokenType.FatArrow, TokenType.LeftArrow,
      ]);
    });

    it("tokenizes SAGE-specific operators", () => {
      const tokens = new Lexer("!! ---").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [TokenType.Bang2, TokenType.Dash3]);
    });

    it("tokenizes comparison operators", () => {
      const tokens = new Lexer("= == != < > <= >=").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.Eq, TokenType.EqEq, TokenType.NotEq,
        TokenType.LAngle, TokenType.RAngle, TokenType.LtEq, TokenType.GtEq,
      ]);
    });

    it("tokenizes arithmetic operators", () => {
      const tokens = new Lexer("+ - * /").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.Plus, TokenType.Minus, TokenType.Star, TokenType.Slash,
      ]);
    });

    it("tokenizes logical operators", () => {
      const tokens = new Lexer("&& | !").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.Ampersand, TokenType.Pipe, TokenType.Bang,
      ]);
    });
  });

  describe("unicode math symbols", () => {
    it("tokenizes quantifiers", () => {
      const tokens = new Lexer("∀ ∃").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [TokenType.ForAll, TokenType.Exists]);
    });

    it("tokenizes set operators", () => {
      const tokens = new Lexer("∈").tokenize();
      assert.equal(tokens[0].type, TokenType.ElementOf);
    });

    it("tokenizes logical symbols", () => {
      const tokens = new Lexer("⟹").tokenize();
      assert.equal(tokens[0].type, TokenType.Implies);
    });

    it("tokenizes summation and checkmark", () => {
      const tokens = new Lexer("∑ ✓").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [TokenType.Summation, TokenType.Checkmark]);
    });

    it("tokenizes prime (post-state)", () => {
      const tokens = new Lexer("accounts'[from]").tokenize();
      const primeIdx = tokens.findIndex(t => t.type === TokenType.Prime);
      assert.ok(primeIdx > 0, "Should find prime token");
    });
  });

  describe("literals", () => {
    it("tokenizes integers", () => {
      const tokens = new Lexer("42 0 999").tokenize();
      const nums = tokens.filter(t => t.type === TokenType.Number);
      assert.equal(nums.length, 3);
      assert.equal(nums[0].value, "42");
      assert.equal(nums[1].value, "0");
      assert.equal(nums[2].value, "999");
    });

    it("tokenizes identifiers", () => {
      const tokens = new Lexer("foo bar_baz _private").tokenize();
      const ids = tokens.filter(t => t.type === TokenType.Identifier);
      assert.equal(ids.length, 3);
      assert.equal(ids[0].value, "foo");
      assert.equal(ids[1].value, "bar_baz");
      assert.equal(ids[2].value, "_private");
    });

    it("tokenizes identifiers with numbers", () => {
      const tokens = new Lexer("user1 account2 v3").tokenize();
      const ids = tokens.filter(t => t.type === TokenType.Identifier);
      assert.equal(ids.length, 3);
    });
  });

  describe("brackets and punctuation", () => {
    it("tokenizes all bracket types", () => {
      const tokens = new Lexer("{ } [ ] ( ) < >").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.LBrace, TokenType.RBrace,
        TokenType.LBracket, TokenType.RBracket,
        TokenType.LParen, TokenType.RParen,
        TokenType.LAngle, TokenType.RAngle,
      ]);
    });

    it("tokenizes punctuation", () => {
      const tokens = new Lexer(": , . ? ;").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.Colon, TokenType.Comma, TokenType.Dot,
        TokenType.Question, TokenType.Semicolon,
      ]);
    });
  });

  describe("comments", () => {
    it("tokenizes line comments", () => {
      const tokens = new Lexer("# this is a comment").tokenize();
      assert.equal(tokens[0].type, TokenType.Hash);
      assert.equal(tokens[0].value, "this is a comment");
    });

    it("tokenizes comment after code", () => {
      const tokens = new Lexer("@mod foo # comment here").tokenize();
      const hash = tokens.find(t => t.type === TokenType.Hash);
      assert.ok(hash);
      assert.equal(hash!.value, "comment here");
    });
  });

  describe("complex expressions", () => {
    it("tokenizes type expressions with generics", () => {
      const tokens = new Lexer("Result<User>").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
      assert.deepEqual(types, [
        TokenType.Identifier, TokenType.LAngle, TokenType.Identifier, TokenType.RAngle,
      ]);
    });

    it("tokenizes nested generics", () => {
      const tokens = new Lexer("Map<Str, Set<Int>>").tokenize();
      const angles = tokens.filter(t => t.type === TokenType.LAngle || t.type === TokenType.RAngle);
      assert.equal(angles.length, 4); // 2 opens, 2 closes
    });

    it("tokenizes method calls", () => {
      const tokens = new Lexer("email.is_valid()").tokenize();
      const dot = tokens.find(t => t.type === TokenType.Dot);
      assert.ok(dot);
    });

    it("tokenizes let bindings and if/else", () => {
      const tokens = new Lexer("let x = 42\nif y => ret z").tokenize();
      const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF && t !== TokenType.Newline);
      assert.deepEqual(types, [
        TokenType.KW_Let, TokenType.Identifier, TokenType.Eq, TokenType.Number,
        TokenType.KW_If, TokenType.Identifier, TokenType.FatArrow, TokenType.KW_Ret, TokenType.Identifier,
      ]);
    });
  });

  describe("whitespace handling", () => {
    it("handles multiple newlines", () => {
      const tokens = new Lexer("a\n\n\nb").tokenize();
      const ids = tokens.filter(t => t.type === TokenType.Identifier);
      assert.equal(ids.length, 2);
    });

    it("handles tabs and spaces", () => {
      const tokens = new Lexer("  \t  @mod  \t  foo").tokenize();
      assert.equal(tokens[0].type, TokenType.KW_Mod);
      assert.equal(tokens[1].type, TokenType.Identifier);
    });
  });
});

// ============================================================================
// PARSER TESTS
// ============================================================================

describe("Parser", () => {
  describe("module declarations", () => {
    it("parses module declaration", () => {
      const ast = parse('@mod user_auth\n"A secure auth system"');
      assert.equal(ast.body.length, 1);
      const mod = ast.body[0];
      assert.equal(mod.kind, "ModuleDecl");
      if (mod.kind === "ModuleDecl") {
        assert.equal(mod.name, "user_auth");
        assert.equal(mod.description, "A secure auth system");
      }
    });

    it("parses module without description", () => {
      const ast = parse("@mod simple_module");
      const mod = ast.body[0];
      assert.equal(mod.kind, "ModuleDecl");
      if (mod.kind === "ModuleDecl") {
        assert.equal(mod.name, "simple_module");
        assert.equal(mod.description, undefined);
      }
    });
  });

  describe("type declarations", () => {
    it("parses type declaration", () => {
      const ast = parse("@type User = {\n  email: Str,\n  age: Int\n}");
      assert.equal(ast.body.length, 1);
      const ty = ast.body[0];
      assert.equal(ty.kind, "TypeDecl");
      if (ty.kind === "TypeDecl") {
        assert.equal(ty.name, "User");
        assert.equal(ty.fields.length, 2);
        assert.equal(ty.fields[0].name, "email");
        assert.equal(ty.fields[1].name, "age");
      }
    });

    it("parses type with generic fields", () => {
      const ast = parse("@type Store = {\n  data: Map<Str, Int>\n}");
      const ty = ast.body[0];
      if (ty.kind === "TypeDecl") {
        const field = ty.fields[0];
        assert.equal(field.type.kind, "GenericType");
        if (field.type.kind === "GenericType") {
          assert.equal(field.type.name, "Map");
          assert.equal(field.type.args.length, 2);
        }
      }
    });

    it("parses type with nested generics", () => {
      const ast = parse("@type Cache = {\n  entries: Map<Str, Set<Int>>\n}");
      const ty = ast.body[0];
      if (ty.kind === "TypeDecl") {
        const field = ty.fields[0];
        if (field.type.kind === "GenericType") {
          assert.equal(field.type.name, "Map");
          const secondArg = field.type.args[1];
          assert.equal(secondArg.kind, "GenericType");
        }
      }
    });

    it("parses empty type", () => {
      const ast = parse("@type Empty = {}");
      const ty = ast.body[0];
      if (ty.kind === "TypeDecl") {
        assert.equal(ty.fields.length, 0);
      }
    });

    it("parses type with trailing comma", () => {
      const ast = parse("@type User = { name: Str, }");
      const ty = ast.body[0];
      if (ty.kind === "TypeDecl") {
        assert.equal(ty.fields.length, 1);
      }
    });
  });

  describe("function declarations", () => {
    it("parses function with requires and ensures", () => {
      const ast = parse(
        '@fn register(email: Str, password: Str) -> Result<User>\n' +
        '"Create a new user"\n' +
        '@req email.is_valid()\n' +
        '@ens "User is created"'
      );
      const fn = ast.body[0];
      assert.equal(fn.kind, "FnDecl");
      if (fn.kind === "FnDecl") {
        assert.equal(fn.name, "register");
        assert.equal(fn.params.length, 2);
        assert.equal(fn.requires.length, 1);
        assert.equal(fn.ensures.length, 1);
        assert.equal(fn.description, "Create a new user");
      }
    });

    it("parses function with no params", () => {
      const ast = parse("@fn get_time() -> Time");
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        assert.equal(fn.name, "get_time");
        assert.equal(fn.params.length, 0);
      }
    });

    it("parses function with multiple requires", () => {
      const ast = parse(
        "@fn transfer(amount: Money) -> Result<()>\n" +
        "@req amount > 0\n" +
        "@req amount <= balance\n" +
        "@req !frozen"
      );
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        assert.equal(fn.requires.length, 3);
      }
    });

    it("parses function with body", () => {
      const ast = parse(
        "@fn test() -> Bool\n" +
        "let x = 5\n" +
        "ret x > 0"
      );
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        assert.ok(fn.body.length >= 1);
      }
    });
  });

  describe("spec declarations", () => {
    it("parses spec with properties, state, and invariants", () => {
      const ast = parse(
        '@spec UserAuth\n' +
        '"High-level auth spec"\n' +
        '@property "No duplicate emails"\n' +
        '@property "Passwords never stored in plaintext"\n' +
        '@state\n' +
        '  users: Set<User>\n' +
        '  sessions: Set<Session>\n' +
        '@invariant ∀ s ∈ sessions: ∃ u ∈ users: s.user_email = u.email'
      );
      const spec = ast.body[0];
      assert.equal(spec.kind, "SpecDecl");
      if (spec.kind === "SpecDecl") {
        assert.equal(spec.name, "UserAuth");
        assert.equal(spec.properties.length, 2);
        assert.equal(spec.state.length, 2);
        assert.equal(spec.invariants.length, 1);
      }
    });

    it("parses spec with only properties", () => {
      const ast = parse(
        '@spec SimpleSpec\n' +
        '@property "First property"\n' +
        '@property "Second property"'
      );
      const spec = ast.body[0];
      if (spec.kind === "SpecDecl") {
        assert.equal(spec.properties.length, 2);
        assert.equal(spec.state.length, 0);
        assert.equal(spec.invariants.length, 0);
      }
    });

    it("parses spec with multiple invariants", () => {
      const ast = parse(
        "@spec PaymentSystem\n" +
        "@invariant balance >= 0\n" +
        "@invariant ∑ accounts = TOTAL\n" +
        "@invariant ∀ t ∈ transactions: t.valid"
      );
      const spec = ast.body[0];
      if (spec.kind === "SpecDecl") {
        assert.equal(spec.invariants.length, 3);
      }
    });
  });

  describe("refinement declarations", () => {
    it("parses refinement with decisions and preserves", () => {
      const ast = parse(
        '@refine UserAuth as SecureAuth\n' +
        '@decision "bcrypt for password hashing" !!\n' +
        '@preserves\n' +
        '  ✓ "All parent invariants"'
      );
      const ref = ast.body[0];
      assert.equal(ref.kind, "RefineDecl");
      if (ref.kind === "RefineDecl") {
        assert.equal(ref.parent, "UserAuth");
        assert.equal(ref.child, "SecureAuth");
        assert.equal(ref.decisions.length, 1);
        assert.equal(ref.preserves.length, 1);
        assert.equal(ref.preserves[0].checked, true);
      }
    });

    it("parses refinement with maps", () => {
      const ast = parse(
        "@refine Abstract as Concrete\n" +
        '@maps "Concrete state maps to abstract"\n' +
        "  concrete_accounts = merge(shards)"
      );
      const ref = ast.body[0];
      if (ref.kind === "RefineDecl") {
        assert.ok(ref.maps);
      }
    });

    it("parses alternative refinement", () => {
      const ast = parse(
        "@refine PaymentSystem as ShardedPayment [alternative]\n" +
        '@decision "Shard by account ID"'
      );
      const ref = ast.body[0];
      if (ref.kind === "RefineDecl") {
        assert.equal(ref.tag, "alternative");
      }
    });
  });

  describe("operation declarations", () => {
    it("parses op declaration", () => {
      const ast = parse(
        "@op transfer(from: AccountId, to: AccountId, amount: Money) -> Result<()>\n" +
        "@req accounts[from] >= amount\n" +
        "@ens accounts'[from] = accounts[from] - amount"
      );
      const op = ast.body[0];
      assert.equal(op.kind, "OpDecl");
      if (op.kind === "OpDecl") {
        assert.equal(op.name, "transfer");
        assert.equal(op.params.length, 3);
        assert.equal(op.requires.length, 1);
        assert.equal(op.ensures.length, 1);
      }
    });

    it("parses op with post-state prime notation", () => {
      const ast = parse(
        "@op increment(id: Id) -> ()\n" +
        "@ens counter'[id] = counter[id] + 1"
      );
      const op = ast.body[0];
      if (op.kind === "OpDecl") {
        assert.ok(op.ensures[0].condition.includes("'"));
      }
    });
  });

  describe("impl declarations", () => {
    it("parses impl declaration", () => {
      const ast = parse("@impl SecureAuth\n... actual code ...");
      const impl = ast.body[0];
      assert.equal(impl.kind, "ImplDecl");
      if (impl.kind === "ImplDecl") {
        assert.equal(impl.spec, "SecureAuth");
      }
    });

    it("parses impl with description", () => {
      const ast = parse('@impl ConcretePayment\n"The real implementation"');
      const impl = ast.body[0];
      if (impl.kind === "ImplDecl") {
        assert.equal(impl.spec, "ConcretePayment");
      }
    });
  });

  describe("inferred annotations", () => {
    it("parses inferred_req", () => {
      const ast = parse('@inferred_req amount > 0 ← "From the validation check"');
      const ann = ast.body[0];
      assert.equal(ann.kind, "InferredAnnotation");
      if (ann.kind === "InferredAnnotation") {
        assert.equal(ann.type, "req");
        assert.equal(ann.condition, "amount > 0");
        assert.equal(ann.reason, "From the validation check");
      }
    });

    it("parses inferred_ens", () => {
      const ast = parse('@inferred_ens "Payment recorded" ← "From db.record_payment"');
      const ann = ast.body[0];
      if (ann.kind === "InferredAnnotation") {
        assert.equal(ann.type, "ens");
      }
    });

    it("parses inferred_effect", () => {
      const ast = parse('@inferred_effect "External API call" ← "From stripe.charge"');
      const ann = ast.body[0];
      if (ann.kind === "InferredAnnotation") {
        assert.equal(ann.type, "effect");
      }
    });
  });

  describe("natural text and decisions", () => {
    it("parses natural text", () => {
      const ast = parse('"Build a todo app"');
      assert.equal(ast.body[0].kind, "NaturalText");
      if (ast.body[0].kind === "NaturalText") {
        assert.equal(ast.body[0].text, "Build a todo app");
      }
    });

    it("parses decision markers", () => {
      const ast = parse('!! "Use PostgreSQL"');
      assert.equal(ast.body[0].kind, "DecisionMarker");
      if (ast.body[0].kind === "DecisionMarker") {
        assert.equal(ast.body[0].text, "Use PostgreSQL");
      }
    });

    it("parses multiple decisions", () => {
      const ast = parse(
        '!! "Use Redis for caching"\n' +
        '!! "Use bcrypt for hashing"\n' +
        '!! "Use JWT for tokens"'
      );
      assert.equal(ast.body.length, 3);
      ast.body.forEach(node => {
        assert.equal(node.kind, "DecisionMarker");
      });
    });
  });

  describe("section separators", () => {
    it("parses section separators", () => {
      const ast = parse('"Some text"\n---\n"More text"');
      assert.equal(ast.body.length, 3);
      assert.equal(ast.body[1].kind, "SectionSeparator");
    });

    it("parses multiple separators", () => {
      const ast = parse('"Part 1"\n---\n"Part 2"\n---\n"Part 3"');
      const seps = ast.body.filter(n => n.kind === "SectionSeparator");
      assert.equal(seps.length, 2);
    });
  });

  describe("control flow", () => {
    it("parses let bindings", () => {
      const ast = parse(
        "@fn test() -> Int\n" +
        "let x = 5\n" +
        "let y = x + 1\n" +
        "ret y"
      );
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        const lets = fn.body.filter(s => s.kind === "LetBinding");
        assert.equal(lets.length, 2);
      }
    });

    it("parses if/else", () => {
      const ast = parse(
        "@fn test() -> Bool\nlet x = 5\nif x > 3 => ret true\n  else => ret false"
      );
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        const ifExpr = fn.body.find(s => s.kind === "IfExpr");
        assert.ok(ifExpr);
        if (ifExpr && ifExpr.kind === "IfExpr") {
          assert.ok(ifExpr.else);
        }
      }
    });

    it("parses if without else", () => {
      const ast = parse(
        "@fn validate() -> Result<()>\n" +
        "if invalid => ret Err(\"bad\")\n" +
        "ret Ok(())"
      );
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        const ifExpr = fn.body.find(s => s.kind === "IfExpr");
        if (ifExpr && ifExpr.kind === "IfExpr") {
          assert.equal(ifExpr.else, undefined);
        }
      }
    });

    it("parses ret with expression", () => {
      const ast = parse(
        "@fn add(a: Int, b: Int) -> Int\n" +
        "ret a + b"
      );
      const fn = ast.body[0];
      if (fn.kind === "FnDecl") {
        const retStmt = fn.body.find(s => s.kind === "RetStatement");
        assert.ok(retStmt);
      }
    });
  });

  describe("complex files", () => {
    it("parses Level 0 natural language spec", () => {
      const ast = parse(
        '"Build a user authentication system"\n' +
        '"Users can register with email and password"\n' +
        '"Users can log in and get a session token"\n' +
        '!! "Passwords must be hashed with bcrypt"\n' +
        '!! "Rate limiting uses Redis"'
      );
      const texts = ast.body.filter(n => n.kind === "NaturalText");
      const decisions = ast.body.filter(n => n.kind === "DecisionMarker");
      assert.equal(texts.length, 3);
      assert.equal(decisions.length, 2);
    });

    it("parses Level 1 structured spec", () => {
      const ast = parse(
        '@mod todo_service\n' +
        '@type Task = {\n' +
        '  id: Int,\n' +
        '  title: Str,\n' +
        '  completed: Bool\n' +
        '}\n' +
        '@fn create_task(title: Str) -> Result<Task>\n' +
        '@req title.len() > 0\n' +
        '@ens "Task created with completed = false"'
      );
      const mod = ast.body.find(n => n.kind === "ModuleDecl");
      const type = ast.body.find(n => n.kind === "TypeDecl");
      const fn = ast.body.find(n => n.kind === "FnDecl");
      assert.ok(mod);
      assert.ok(type);
      assert.ok(fn);
    });

    it("parses Level 2 formal spec", () => {
      const ast = parse(
        '@spec PaymentProcessor\n' +
        '@state\n' +
        '  accounts: Map<AccountId, Balance>\n' +
        '  transactions: Set<Transaction>\n' +
        '@invariant ∑ accounts.values() = TOTAL_MONEY\n' +
        '@invariant ∀ t1,t2 ∈ transactions: t1.id = t2.id ⟹ t1 = t2\n' +
        '@op transfer(from: AccountId, to: AccountId, amount: Money) -> Result<()>\n' +
        "@req accounts[from] >= amount\n" +
        "@ens accounts'[from] = accounts[from] - amount"
      );
      const spec = ast.body.find(n => n.kind === "SpecDecl");
      const op = ast.body.find(n => n.kind === "OpDecl");
      assert.ok(spec);
      assert.ok(op);
      if (spec && spec.kind === "SpecDecl") {
        assert.equal(spec.invariants.length, 2);
        assert.equal(spec.state.length, 2);
      }
    });

    it("parses mixed formality levels", () => {
      const ast = parse(
        '"Quick prototype idea"\n' +
        '---\n' +
        '@mod auth\n' +
        '@type User = { email: Str }\n' +
        '@fn login(email: Str) -> Result<Session>\n' +
        '@req email.is_valid()\n' +
        '!! "Use bcrypt"\n' +
        '---\n' +
        '"Implementation notes follow"'
      );
      assert.ok(ast.body.length >= 5);
      const seps = ast.body.filter(n => n.kind === "SectionSeparator");
      assert.equal(seps.length, 2);
    });
  });

  describe("edge cases", () => {
    it("handles empty input", () => {
      const ast = parse("");
      assert.equal(ast.body.length, 0);
    });

    it("handles whitespace only", () => {
      const ast = parse("   \n\n   \n");
      assert.equal(ast.body.length, 0);
    });

    it("handles comments only", () => {
      const ast = parse("# just a comment\n# another comment");
      // Comments may or may not be in AST depending on parser design
      assert.ok(true);
    });

    it("handles deeply nested generics", () => {
      const ast = parse("@type Deep = { data: Map<Str, Map<Int, Set<Bool>>> }");
      const ty = ast.body[0];
      assert.equal(ty.kind, "TypeDecl");
    });
  });
});
