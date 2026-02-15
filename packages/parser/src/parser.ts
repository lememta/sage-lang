import { Token, TokenType, Lexer } from "./lexer";
import {
  SageFile, TopLevel, ModuleDecl, TypeDecl, FieldDef, TypeExpr,
  NamedType, GenericType, RecordType, Param, FnDecl, Requirement,
  Ensures, SpecDecl, Property, StateField, Invariant, OpDecl,
  RefineDecl, DecisionMarker, Preserves, MapsClause, CompareWith,
  ImplDecl, LetBinding, IfExpr, RetStatement, NaturalText,
  SectionSeparator, InferredAnnotation, Statement, RawExpression,
  Comment, Span, Loc,
} from "./ast";

export class ParseError extends Error {
  constructor(message: string, public loc: Loc) {
    super(`${message} at line ${loc.line}, col ${loc.col}`);
    this.name = "ParseError";
  }
}

export class Parser {
  private tokens: Token[];
  private pos: number = 0;

  constructor(tokens: Token[]) {
    this.tokens = tokens;
  }

  // ── Entry ───────────────────────────────────────────────────────
  parse(): SageFile {
    const body: TopLevel[] = [];
    this.skipNewlines();

    while (!this.isAtEnd()) {
      const node = this.parseTopLevel();
      if (node) body.push(node);
      this.skipNewlines();
    }

    const start: Loc = { line: 1, col: 1, offset: 0 };
    const end = this.current().span.end;
    return { kind: "File", body, span: { start, end } };
  }

  // ── Top-level dispatcher ────────────────────────────────────────
  private parseTopLevel(): TopLevel | null {
    const tok = this.current();

    switch (tok.type) {
      case TokenType.KW_Mod: return this.parseModuleDecl();
      case TokenType.KW_Type: return this.parseTypeDecl();
      case TokenType.KW_Fn: return this.parseFnDecl();
      case TokenType.KW_Spec: return this.parseSpecDecl();
      case TokenType.KW_Op: return this.parseOpDecl();
      case TokenType.KW_Refine: return this.parseRefineDecl();
      case TokenType.KW_Impl: return this.parseImplDecl();
      case TokenType.KW_InferredReq:
      case TokenType.KW_InferredEns:
      case TokenType.KW_InferredEffect:
        return this.parseInferredAnnotation();
      case TokenType.String: return this.parseNaturalText();
      case TokenType.Bang2: return this.parseDecisionMarker();
      case TokenType.Dash3: return this.parseSectionSeparator();
      case TokenType.Hash: return this.parseComment();
      case TokenType.KW_Let: return this.parseLetBinding();
      case TokenType.KW_If: return this.parseIfExpr();
      case TokenType.KW_Ret: return this.parseRetStatement();
      case TokenType.EOF: return null;
      default:
        // Consume rest of line as raw expression
        return this.parseRawLine();
    }
  }

  // ── @mod ────────────────────────────────────────────────────────
  private parseModuleDecl(): ModuleDecl {
    const start = this.expect(TokenType.KW_Mod).span.start;
    const name = this.expect(TokenType.Identifier).value;
    this.skipNewlines();
    let description: string | undefined;
    if (this.check(TokenType.String)) {
      description = this.advance().value;
    }
    return { kind: "ModuleDecl", name, description, span: this.spanFrom(start) };
  }

  // ── @type ───────────────────────────────────────────────────────
  private parseTypeDecl(): TypeDecl {
    const start = this.expect(TokenType.KW_Type).span.start;
    const name = this.expect(TokenType.Identifier).value;
    this.expect(TokenType.Eq);
    this.expect(TokenType.LBrace);
    this.skipNewlines();
    const fields: FieldDef[] = [];
    while (!this.check(TokenType.RBrace) && !this.isAtEnd()) {
      fields.push(this.parseFieldDef());
      this.skipNewlines();
      if (this.check(TokenType.Comma)) this.advance();
      this.skipNewlines();
    }
    this.expect(TokenType.RBrace);
    return { kind: "TypeDecl", name, fields, span: this.spanFrom(start) };
  }

  private parseFieldDef(): FieldDef {
    const start = this.current().span.start;
    const name = this.expect(TokenType.Identifier).value;
    this.expect(TokenType.Colon);
    const type = this.parseTypeExpr();
    return { kind: "FieldDef", name, type, span: this.spanFrom(start) };
  }

  private parseTypeExpr(): TypeExpr {
    if (this.check(TokenType.LBrace)) {
      return this.parseRecordType();
    }
    // Handle unit type ()
    if (this.check(TokenType.LParen) && this.peek(1)?.type === TokenType.RParen) {
      const start = this.advance().span.start;
      this.advance(); // )
      return { kind: "NamedType", name: "()", span: this.spanFrom(start) } as NamedType;
    }
    const start = this.current().span.start;
    const name = this.expect(TokenType.Identifier).value;
    if (this.check(TokenType.LAngle)) {
      this.advance(); // <
      const args: TypeExpr[] = [];
      args.push(this.parseTypeExpr());
      while (this.check(TokenType.Comma)) {
        this.advance();
        args.push(this.parseTypeExpr());
      }
      this.expect(TokenType.RAngle);
      return { kind: "GenericType", name, args, span: this.spanFrom(start) } as GenericType;
    }
    return { kind: "NamedType", name, span: this.spanFrom(start) } as NamedType;
  }

  private parseRecordType(): RecordType {
    const start = this.expect(TokenType.LBrace).span.start;
    this.skipNewlines();
    const fields: FieldDef[] = [];
    while (!this.check(TokenType.RBrace) && !this.isAtEnd()) {
      if (this.check(TokenType.Identifier)) {
        fields.push(this.parseFieldDef());
      }
      this.skipNewlines();
      if (this.check(TokenType.Comma)) this.advance();
      if (this.check(TokenType.Ellipsis)) { this.advance(); break; }
      this.skipNewlines();
    }
    if (this.check(TokenType.RBrace)) this.advance();
    return { kind: "RecordType", fields, span: this.spanFrom(start) };
  }

  // ── @fn ─────────────────────────────────────────────────────────
  private parseFnDecl(): FnDecl {
    const start = this.expect(TokenType.KW_Fn).span.start;
    const name = this.expect(TokenType.Identifier).value;
    const params = this.parseParamList();
    let returnType: TypeExpr | undefined;
    if (this.check(TokenType.Arrow)) {
      this.advance();
      returnType = this.parseTypeExpr();
    }
    this.skipNewlines();

    let description: string | undefined;
    if (this.check(TokenType.String)) {
      description = this.advance().value;
      this.skipNewlines();
    }

    const requires: Requirement[] = [];
    const ensures: Ensures[] = [];
    while (this.check(TokenType.KW_Req) || this.check(TokenType.KW_Ens)) {
      if (this.check(TokenType.KW_Req)) {
        requires.push(this.parseRequirement());
      } else {
        ensures.push(this.parseEnsures());
      }
      this.skipNewlines();
    }

    const body = this.parseBody();
    return {
      kind: "FnDecl", name, params, returnType, description,
      requires, ensures, body, span: this.spanFrom(start),
    };
  }

  private parseParamList(): Param[] {
    const params: Param[] = [];
    if (!this.check(TokenType.LParen)) return params;
    this.advance(); // (
    while (!this.check(TokenType.RParen) && !this.isAtEnd()) {
      params.push(this.parseParam());
      if (this.check(TokenType.Comma)) this.advance();
    }
    this.expect(TokenType.RParen);
    return params;
  }

  private parseParam(): Param {
    const start = this.current().span.start;
    const name = this.expect(TokenType.Identifier).value;
    let type: TypeExpr | undefined;
    if (this.check(TokenType.Colon)) {
      this.advance();
      type = this.parseTypeExpr();
    }
    return { kind: "Param", name, type, span: this.spanFrom(start) };
  }

  private parseRequirement(): Requirement {
    const start = this.expect(TokenType.KW_Req).span.start;
    const condition = this.consumeRestOfLine();
    return { kind: "Requirement", condition, span: this.spanFrom(start) };
  }

  private parseEnsures(): Ensures {
    const start = this.expect(TokenType.KW_Ens).span.start;
    const condition = this.consumeRestOfLine();
    return { kind: "Ensures", condition, span: this.spanFrom(start) };
  }

  // ── @spec ───────────────────────────────────────────────────────
  private parseSpecDecl(): SpecDecl {
    const start = this.expect(TokenType.KW_Spec).span.start;
    const name = this.expect(TokenType.Identifier).value;
    this.skipNewlines();

    let description: string | undefined;
    if (this.check(TokenType.String)) {
      description = this.advance().value;
      this.skipNewlines();
    }

    const properties: Property[] = [];
    const state: StateField[] = [];
    const invariants: Invariant[] = [];

    while (
      this.check(TokenType.KW_Property) ||
      this.check(TokenType.KW_State) ||
      this.check(TokenType.KW_Invariant)
    ) {
      if (this.check(TokenType.KW_Property)) {
        properties.push(this.parseProperty());
      } else if (this.check(TokenType.KW_State)) {
        state.push(...this.parseStateBlock());
      } else {
        invariants.push(this.parseInvariant());
      }
      this.skipNewlines();
    }

    return {
      kind: "SpecDecl", name, description, properties, state, invariants,
      span: this.spanFrom(start),
    };
  }

  private parseProperty(): Property {
    const start = this.expect(TokenType.KW_Property).span.start;
    const description = this.check(TokenType.String) ? this.advance().value : this.consumeRestOfLine();
    return { kind: "Property", description, span: this.spanFrom(start) };
  }

  private parseStateBlock(): StateField[] {
    this.expect(TokenType.KW_State);
    this.skipNewlines();
    const fields: StateField[] = [];
    while (this.check(TokenType.Identifier) && !this.isAtKeyword()) {
      const start = this.current().span.start;
      const name = this.advance().value;
      this.expect(TokenType.Colon);
      const type = this.parseTypeExpr();
      fields.push({ kind: "StateField", name, type, span: this.spanFrom(start) });
      this.skipNewlines();
    }
    return fields;
  }

  private parseInvariant(): Invariant {
    const start = this.expect(TokenType.KW_Invariant).span.start;
    let expression = this.consumeRestOfLine();
    // Check if next line is indented continuation (expression body)
    this.skipNewlines();
    while (
      !this.isAtEnd() &&
      !this.isAtKeyword() &&
      !this.check(TokenType.Dash3) &&
      !this.check(TokenType.String) &&
      !this.check(TokenType.Hash) &&
      !this.check(TokenType.Newline) &&
      !this.check(TokenType.EOF)
    ) {
      expression += " " + this.consumeRestOfLine();
      this.skipNewlines();
    }
    return { kind: "Invariant", expression: expression.trim(), span: this.spanFrom(start) };
  }

  // ── @op ─────────────────────────────────────────────────────────
  private parseOpDecl(): OpDecl {
    const start = this.expect(TokenType.KW_Op).span.start;
    const name = this.expect(TokenType.Identifier).value;
    const params = this.parseParamList();
    let returnType: TypeExpr | undefined;
    if (this.check(TokenType.Arrow)) {
      this.advance();
      returnType = this.parseTypeExpr();
    }
    this.skipNewlines();

    const requires: Requirement[] = [];
    const ensures: Ensures[] = [];
    while (this.check(TokenType.KW_Req) || this.check(TokenType.KW_Ens)) {
      if (this.check(TokenType.KW_Req)) requires.push(this.parseRequirement());
      else ensures.push(this.parseEnsures());
      this.skipNewlines();
    }

    const body = this.parseBody();
    return {
      kind: "OpDecl", name, params, returnType, requires, ensures, body,
      span: this.spanFrom(start),
    };
  }

  // ── @refine ─────────────────────────────────────────────────────
  private parseRefineDecl(): RefineDecl {
    const start = this.expect(TokenType.KW_Refine).span.start;
    const parent = this.expect(TokenType.Identifier).value;
    let child: string | undefined;
    let tag: string | undefined;

    if (this.check(TokenType.KW_As)) {
      this.advance();
      child = this.expect(TokenType.Identifier).value;
      if (this.check(TokenType.LBracket)) {
        this.advance();
        tag = this.expect(TokenType.Identifier).value;
        this.expect(TokenType.RBracket);
      }
    }
    this.skipNewlines();

    let description: string | undefined;
    if (this.check(TokenType.String)) {
      description = this.advance().value;
      this.skipNewlines();
    }

    const decisions: DecisionMarker[] = [];
    const state: StateField[] = [];
    const preserves: Preserves[] = [];
    const maps: MapsClause[] = [];
    let compareWith: CompareWith | undefined;

    while (!this.isAtEnd()) {
      this.skipNewlines();
      if (this.check(TokenType.KW_Decision)) {
        const dStart = this.advance().span.start;
        const text = this.check(TokenType.String) ? this.advance().value : this.consumeRestOfLine();
        // consume optional trailing !!
        if (this.check(TokenType.Bang2)) this.advance();
        decisions.push({ kind: "DecisionMarker", text, span: this.spanFrom(dStart) });
      } else if (this.check(TokenType.String)) {
        // Natural language in refinement — could be a description/decision
        const txt = this.advance().value;
        // Check if followed by !!
        if (this.check(TokenType.Bang2)) {
          this.advance();
          decisions.push({ kind: "DecisionMarker", text: txt, span: this.spanFrom(start) });
        } else {
          if (!description) description = txt;
        }
      } else if (this.check(TokenType.Bang2)) {
        decisions.push(this.parseDecisionMarkerNode());
      } else if (this.check(TokenType.KW_State)) {
        state.push(...this.parseStateBlock());
      } else if (this.check(TokenType.KW_Preserves)) {
        preserves.push(...this.parsePreservesBlock());
      } else if (this.check(TokenType.KW_Maps)) {
        maps.push(this.parseMapsClause());
      } else if (this.check(TokenType.KW_CompareWith)) {
        compareWith = this.parseCompareWith();
      } else {
        break;
      }
    }

    return {
      kind: "RefineDecl", parent, child, tag, decisions, state,
      preserves, maps, compareWith, description, span: this.spanFrom(start),
    };
  }

  private parsePreservesBlock(): Preserves[] {
    const result: Preserves[] = [];
    this.expect(TokenType.KW_Preserves);
    this.skipNewlines();

    // Could be a single string or a block with ✓ items
    if (this.check(TokenType.String)) {
      const start = this.current().span.start;
      result.push({
        kind: "Preserves", description: this.advance().value,
        checked: false, span: this.spanFrom(start),
      });
    }

    while (this.check(TokenType.Checkmark)) {
      const start = this.advance().span.start;
      const desc = this.check(TokenType.String) ? this.advance().value : this.consumeRestOfLine();
      result.push({ kind: "Preserves", description: desc, checked: true, span: this.spanFrom(start) });
      this.skipNewlines();
    }

    return result;
  }

  private parseMapsClause(): MapsClause {
    const start = this.expect(TokenType.KW_Maps).span.start;
    const description = this.check(TokenType.String) ? this.advance().value : this.consumeRestOfLine();
    // consume any indented continuation lines
    this.skipNewlines();
    return { kind: "MapsClause", description, span: this.spanFrom(start) };
  }

  private parseCompareWith(): CompareWith {
    const start = this.expect(TokenType.KW_CompareWith).span.start;
    const target = this.expect(TokenType.Identifier).value;
    this.skipNewlines();
    let advantages: string | undefined;
    let disadvantages: string | undefined;
    // Look for advantages:/disadvantages: lines
    while (this.check(TokenType.Identifier)) {
      const key = this.current().value;
      if (key === "advantages") {
        this.advance();
        this.expect(TokenType.Colon);
        advantages = this.check(TokenType.String) ? this.advance().value : this.consumeRestOfLine();
        this.skipNewlines();
      } else if (key === "disadvantages") {
        this.advance();
        this.expect(TokenType.Colon);
        disadvantages = this.check(TokenType.String) ? this.advance().value : this.consumeRestOfLine();
        this.skipNewlines();
      } else {
        break;
      }
    }
    return { kind: "CompareWith", target, advantages, disadvantages, span: this.spanFrom(start) };
  }

  // ── @impl ───────────────────────────────────────────────────────
  private parseImplDecl(): ImplDecl {
    const start = this.expect(TokenType.KW_Impl).span.start;
    let spec: string | undefined;
    if (this.check(TokenType.Identifier)) {
      spec = this.advance().value;
    }
    this.skipNewlines();

    // Consume body as raw text until next top-level construct or ---
    let body = "";
    while (
      !this.isAtEnd() &&
      !this.isAtKeyword() &&
      !this.check(TokenType.Dash3) &&
      !this.check(TokenType.Hash)
    ) {
      if (this.check(TokenType.Newline)) {
        body += "\n";
        this.advance();
      } else {
        body += this.current().value;
        this.advance();
      }
    }

    return { kind: "ImplDecl", spec, body: body.trim(), span: this.spanFrom(start) };
  }

  // ── Inferred annotations ────────────────────────────────────────
  private parseInferredAnnotation(): InferredAnnotation {
    const tok = this.advance();
    const start = tok.span.start;
    let type: "req" | "ens" | "effect";
    if (tok.type === TokenType.KW_InferredReq) type = "req";
    else if (tok.type === TokenType.KW_InferredEns) type = "ens";
    else type = "effect";

    let condition = this.consumeRestOfLogicalLine();
    let reason: string | undefined;

    // Check for ← reason pattern
    const arrowIdx = condition.indexOf("←");
    if (arrowIdx !== -1) {
      reason = condition.slice(arrowIdx + 1).trim().replace(/^"|"$/g, "");
      condition = condition.slice(0, arrowIdx).trim();
    }
    // Strip surrounding quotes from condition
    condition = condition.replace(/^"|"$/g, "").trim();

    return {
      kind: "InferredAnnotation", type, condition, reason,
      span: this.spanFrom(start),
    };
  }

  // ── Statements ──────────────────────────────────────────────────
  private parseBody(): Statement[] {
    const stmts: Statement[] = [];
    this.skipNewlines();
    while (
      !this.isAtEnd() &&
      !this.isAtTopLevelKeyword()
    ) {
      const stmt = this.parseStatement();
      if (stmt) stmts.push(stmt);
      this.skipNewlines();
    }
    return stmts;
  }

  private parseStatement(): Statement | null {
    if (this.check(TokenType.String)) return this.parseNaturalText();
    if (this.check(TokenType.Bang2)) return this.parseDecisionMarkerOrStatement();
    if (this.check(TokenType.KW_Let)) return this.parseLetBinding();
    if (this.check(TokenType.KW_If)) return this.parseIfExpr();
    if (this.check(TokenType.KW_Ret)) return this.parseRetStatement();
    if (this.check(TokenType.Newline)) { this.advance(); return null; }
    if (this.check(TokenType.Dash3)) return null; // let parent handle
    return this.parseRawLine();
  }

  private parseLetBinding(): LetBinding {
    const decision = this.check(TokenType.Bang2);
    if (decision) this.advance();

    const start = this.expect(TokenType.KW_Let).span.start;
    const name = this.expect(TokenType.Identifier).value;
    this.expect(TokenType.Eq);
    const value = this.consumeRestOfLine();

    // Check for multi-line object literal
    let fullValue = value;
    if (value.trim().endsWith("{") || value.includes("{")) {
      fullValue = this.consumeUntilBalancedOrLine(fullValue);
    }

    return { kind: "LetBinding", name, value: fullValue.trim(), decision, span: this.spanFrom(start) };
  }

  private parseIfExpr(): IfExpr {
    const decision = this.check(TokenType.Bang2);
    if (decision) this.advance();

    const start = this.expect(TokenType.KW_If).span.start;
    // Consume everything up to =>
    let condition = "";
    while (!this.isAtEnd() && !this.check(TokenType.FatArrow) && !this.check(TokenType.Newline)) {
      condition += this.current().value + " ";
      this.advance();
    }
    condition = condition.trim();

    let then = "";
    if (this.check(TokenType.FatArrow)) {
      this.advance();
      then = this.consumeRestOfLine();
    }

    this.skipNewlines();
    let elseClause: string | undefined;
    if (this.check(TokenType.KW_Else)) {
      this.advance();
      if (this.check(TokenType.FatArrow)) this.advance();
      elseClause = this.consumeRestOfLine();
    }

    return { kind: "IfExpr", condition, then: then.trim(), else: elseClause?.trim(), decision, span: this.spanFrom(start) };
  }

  private parseRetStatement(): RetStatement {
    const start = this.expect(TokenType.KW_Ret).span.start;
    const value = this.consumeRestOfLine();
    return { kind: "RetStatement", value: value.trim(), span: this.spanFrom(start) };
  }

  private parseNaturalText(): NaturalText {
    const tok = this.expect(TokenType.String);
    return { kind: "NaturalText", text: tok.value, span: tok.span };
  }

  private parseDecisionMarker(): DecisionMarker {
    const start = this.expect(TokenType.Bang2).span.start;
    let text: string;
    if (this.check(TokenType.String)) {
      text = this.advance().value;
    } else {
      text = this.consumeRestOfLine();
    }
    return { kind: "DecisionMarker", text: text.trim(), span: this.spanFrom(start) };
  }

  private parseDecisionMarkerNode(): DecisionMarker {
    return this.parseDecisionMarker();
  }

  private parseDecisionMarkerOrStatement(): Statement {
    // Peek ahead: if !! is followed by let or if, parse those with decision flag
    if (this.peek(1)?.type === TokenType.KW_Let) {
      return this.parseLetBinding();
    }
    if (this.peek(1)?.type === TokenType.KW_If) {
      return this.parseIfExpr();
    }
    return this.parseDecisionMarker();
  }

  private parseSectionSeparator(): SectionSeparator {
    const tok = this.expect(TokenType.Dash3);
    return { kind: "SectionSeparator", span: tok.span };
  }

  private parseComment(): Comment {
    const tok = this.expect(TokenType.Hash);
    return { kind: "Comment", text: tok.value, span: tok.span };
  }

  private parseRawLine(): RawExpression {
    const start = this.current().span.start;
    let text = "";
    while (!this.isAtEnd() && !this.check(TokenType.Newline)) {
      text += this.current().value + " ";
      this.advance();
    }
    return { kind: "RawExpression", text: text.trim(), span: this.spanFrom(start) };
  }

  // ── Utilities ───────────────────────────────────────────────────
  private current(): Token {
    return this.tokens[this.pos] ?? this.tokens[this.tokens.length - 1];
  }

  private peek(ahead: number): Token | undefined {
    return this.tokens[this.pos + ahead];
  }

  private advance(): Token {
    const tok = this.current();
    this.pos++;
    return tok;
  }

  private check(type: TokenType): boolean {
    return this.current().type === type;
  }

  private expect(type: TokenType): Token {
    if (this.current().type !== type) {
      throw new ParseError(
        `Expected ${type}, got ${this.current().type} ("${this.current().value}")`,
        this.current().span.start,
      );
    }
    return this.advance();
  }

  private isAtEnd(): boolean {
    return this.current().type === TokenType.EOF;
  }

  private skipNewlines() {
    while (this.check(TokenType.Newline)) this.advance();
  }

  private isAtKeyword(): boolean {
    const t = this.current().type;
    return t.startsWith("KW_") && t !== TokenType.KW_Let && t !== TokenType.KW_If &&
      t !== TokenType.KW_Else && t !== TokenType.KW_Ret && t !== TokenType.KW_As;
  }

  private isAtTopLevelKeyword(): boolean {
    const t = this.current().type;
    return t === TokenType.KW_Mod || t === TokenType.KW_Type || t === TokenType.KW_Fn ||
      t === TokenType.KW_Spec || t === TokenType.KW_Op || t === TokenType.KW_Refine ||
      t === TokenType.KW_Impl || t === TokenType.KW_InferredReq ||
      t === TokenType.KW_InferredEns || t === TokenType.KW_InferredEffect ||
      t === TokenType.Dash3 || t === TokenType.Hash;
  }

  private consumeRestOfLine(): string {
    let text = "";
    while (!this.isAtEnd() && !this.check(TokenType.Newline)) {
      const tok = this.current();
      if (tok.type === TokenType.String) {
        text += '"' + tok.value + '"';
      } else {
        text += tok.value;
      }
      text += " ";
      this.advance();
    }
    return text.trim();
  }

  private consumeRestOfLogicalLine(): string {
    let text = "";
    while (!this.isAtEnd() && !this.check(TokenType.Newline)) {
      const tok = this.current();
      if (tok.type === TokenType.String) {
        text += '"' + tok.value + '"';
      } else if (tok.type === TokenType.LeftArrow) {
        text += "←";
      } else {
        text += tok.value;
      }
      text += " ";
      this.advance();
    }
    return text.trim();
  }

  private consumeUntilBalancedOrLine(initial: string): string {
    let text = initial;
    let braces = 0;
    // Count braces in initial
    for (const ch of initial) {
      if (ch === "{") braces++;
      if (ch === "}") braces--;
    }
    if (braces <= 0) return text;

    this.skipNewlines();
    while (!this.isAtEnd() && braces > 0) {
      if (this.check(TokenType.LBrace)) braces++;
      if (this.check(TokenType.RBrace)) braces--;
      if (this.check(TokenType.Newline)) {
        text += "\n";
        this.advance();
        continue;
      }
      text += this.current().value + " ";
      this.advance();
    }
    return text;
  }

  private spanFrom(start: Loc): Span {
    const prev = this.tokens[this.pos - 1] ?? this.current();
    return { start, end: prev.span.end };
  }
}

// ── Convenience ─────────────────────────────────────────────────────
export function parse(source: string): SageFile {
  const lexer = new Lexer(source);
  const tokens = lexer.tokenize();
  const parser = new Parser(tokens);
  return parser.parse();
}
