import { describe, it } from "node:test";
import * as assert from "node:assert/strict";
import { Lexer, TokenType } from "./lexer";
import { parse } from "./parser";

describe("Lexer", () => {
  it("tokenizes @keywords", () => {
    const tokens = new Lexer("@mod @type @fn @req @ens").tokenize();
    const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
    assert.deepEqual(types, [
      TokenType.KW_Mod, TokenType.KW_Type, TokenType.KW_Fn,
      TokenType.KW_Req, TokenType.KW_Ens,
    ]);
  });

  it("tokenizes strings", () => {
    const tokens = new Lexer('"hello world"').tokenize();
    assert.equal(tokens[0].type, TokenType.String);
    assert.equal(tokens[0].value, "hello world");
  });

  it("tokenizes operators", () => {
    const tokens = new Lexer("-> => !! ---").tokenize();
    const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
    assert.deepEqual(types, [
      TokenType.Arrow, TokenType.FatArrow, TokenType.Bang2, TokenType.Dash3,
    ]);
  });

  it("tokenizes unicode math symbols", () => {
    const tokens = new Lexer("∀ ∃ ∈ ⟹ ∑ ✓").tokenize();
    const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
    assert.deepEqual(types, [
      TokenType.ForAll, TokenType.Exists, TokenType.ElementOf,
      TokenType.Implies, TokenType.Summation, TokenType.Checkmark,
    ]);
  });

  it("tokenizes identifiers and plain keywords", () => {
    const tokens = new Lexer("let x = 42\nif y => ret z").tokenize();
    const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF && t !== TokenType.Newline);
    assert.deepEqual(types, [
      TokenType.KW_Let, TokenType.Identifier, TokenType.Eq, TokenType.Number,
      TokenType.KW_If, TokenType.Identifier, TokenType.FatArrow, TokenType.KW_Ret, TokenType.Identifier,
    ]);
  });

  it("tokenizes type expressions with generics", () => {
    const tokens = new Lexer("Result<User>").tokenize();
    const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
    assert.deepEqual(types, [
      TokenType.Identifier, TokenType.LAngle, TokenType.Identifier, TokenType.RAngle,
    ]);
  });

  it("tokenizes line comments", () => {
    const tokens = new Lexer("# this is a comment").tokenize();
    assert.equal(tokens[0].type, TokenType.Hash);
    assert.equal(tokens[0].value, "this is a comment");
  });

  it("tokenizes inferred annotations", () => {
    const tokens = new Lexer("@inferred_req @inferred_ens @inferred_effect").tokenize();
    const types = tokens.map(t => t.type).filter(t => t !== TokenType.EOF);
    assert.deepEqual(types, [
      TokenType.KW_InferredReq, TokenType.KW_InferredEns, TokenType.KW_InferredEffect,
    ]);
  });
});

describe("Parser", () => {
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

  it("parses natural text and decision markers", () => {
    const ast = parse('"Build a todo app"\n!! "Use PostgreSQL"');
    assert.equal(ast.body.length, 2);
    assert.equal(ast.body[0].kind, "NaturalText");
    assert.equal(ast.body[1].kind, "DecisionMarker");
  });

  it("parses section separators", () => {
    const ast = parse('"Some text"\n---\n"More text"');
    assert.equal(ast.body.length, 3);
    assert.equal(ast.body[1].kind, "SectionSeparator");
  });

  it("parses let bindings and if/else", () => {
    const ast = parse(
      '@fn test() -> Bool\nlet x = 5\nif x > 3 => ret true\n  else => ret false'
    );
    const fn = ast.body[0];
    if (fn.kind === "FnDecl") {
      assert.equal(fn.body.length, 2);
      assert.equal(fn.body[0].kind, "LetBinding");
      assert.equal(fn.body[1].kind, "IfExpr");
      if (fn.body[1].kind === "IfExpr") {
        assert.ok(fn.body[1].else);
      }
    }
  });

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

  it("parses inferred annotations", () => {
    const ast = parse('@inferred_req amount > 0 ← "From the validation check"');
    const ann = ast.body[0];
    assert.equal(ann.kind, "InferredAnnotation");
    if (ann.kind === "InferredAnnotation") {
      assert.equal(ann.type, "req");
      assert.equal(ann.condition, "amount > 0");
      assert.equal(ann.reason, "From the validation check");
    }
  });

  it("parses impl declaration", () => {
    const ast = parse("@impl SecureAuth\n... actual code ...");
    const impl = ast.body[0];
    assert.equal(impl.kind, "ImplDecl");
    if (impl.kind === "ImplDecl") {
      assert.equal(impl.spec, "SecureAuth");
    }
  });

  it("parses generic types with multiple args", () => {
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
});
