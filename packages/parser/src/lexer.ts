import { Loc, Span } from "./ast";

// ── Token types ─────────────────────────────────────────────────────
export enum TokenType {
  // Keywords (@ prefixed)
  KW_Mod = "KW_Mod",
  KW_Type = "KW_Type",
  KW_Fn = "KW_Fn",
  KW_Req = "KW_Req",
  KW_Ens = "KW_Ens",
  KW_Spec = "KW_Spec",
  KW_Refine = "KW_Refine",
  KW_Invariant = "KW_Invariant",
  KW_Property = "KW_Property",
  KW_Decision = "KW_Decision",
  KW_Preserves = "KW_Preserves",
  KW_Impl = "KW_Impl",
  KW_Op = "KW_Op",
  KW_State = "KW_State",
  KW_Maps = "KW_Maps",
  KW_InferredReq = "KW_InferredReq",
  KW_InferredEns = "KW_InferredEns",
  KW_InferredEffect = "KW_InferredEffect",
  KW_CompareWith = "KW_CompareWith",

  // Plain keywords
  KW_Let = "KW_Let",
  KW_If = "KW_If",
  KW_Else = "KW_Else",
  KW_Ret = "KW_Ret",
  KW_As = "KW_As",

  // Literals
  String = "String",
  Number = "Number",
  Identifier = "Identifier",

  // Operators & symbols
  Arrow = "Arrow",         // ->
  FatArrow = "FatArrow",   // =>
  Bang2 = "Bang2",         // !!
  Dash3 = "Dash3",         // ---
  Eq = "Eq",               // =
  LParen = "LParen",
  RParen = "RParen",
  LBrace = "LBrace",
  RBrace = "RBrace",
  LBracket = "LBracket",
  RBracket = "RBracket",
  LAngle = "LAngle",       // <
  RAngle = "RAngle",       // >
  Colon = "Colon",
  Comma = "Comma",
  Dot = "Dot",
  Question = "Question",    // ?
  Pipe = "Pipe",            // |
  Ampersand = "Ampersand",  // &
  Plus = "Plus",
  Minus = "Minus",
  Star = "Star",
  Slash = "Slash",
  Bang = "Bang",            // !
  LeftArrow = "LeftArrow",  // ←
  Semicolon = "Semicolon",

  // Math / unicode symbols
  ForAll = "ForAll",        // ∀
  Exists = "Exists",        // ∃
  ElementOf = "ElementOf",  // ∈
  Implies = "Implies",      // ⟹
  Summation = "Summation",  // ∑
  Checkmark = "Checkmark",  // ✓
  Prime = "Prime",          // '

  // Comparison
  GtEq = "GtEq",           // >=
  LtEq = "LtEq",           // <=
  EqEq = "EqEq",           // ==
  NotEq = "NotEq",         // !=

  // Misc
  Hash = "Hash",            // # (comment)
  Ellipsis = "Ellipsis",    // ...
  Newline = "Newline",
  EOF = "EOF",
}

export interface Token {
  type: TokenType;
  value: string;
  span: Span;
}

// ── Keyword map ─────────────────────────────────────────────────────
const AT_KEYWORDS: Record<string, TokenType> = {
  "@mod": TokenType.KW_Mod,
  "@type": TokenType.KW_Type,
  "@fn": TokenType.KW_Fn,
  "@req": TokenType.KW_Req,
  "@ens": TokenType.KW_Ens,
  "@spec": TokenType.KW_Spec,
  "@refine": TokenType.KW_Refine,
  "@invariant": TokenType.KW_Invariant,
  "@property": TokenType.KW_Property,
  "@decision": TokenType.KW_Decision,
  "@preserves": TokenType.KW_Preserves,
  "@impl": TokenType.KW_Impl,
  "@op": TokenType.KW_Op,
  "@state": TokenType.KW_State,
  "@maps": TokenType.KW_Maps,
  "@inferred_req": TokenType.KW_InferredReq,
  "@inferred_ens": TokenType.KW_InferredEns,
  "@inferred_effect": TokenType.KW_InferredEffect,
  "@compare_with": TokenType.KW_CompareWith,
};

const PLAIN_KEYWORDS: Record<string, TokenType> = {
  let: TokenType.KW_Let,
  if: TokenType.KW_If,
  else: TokenType.KW_Else,
  ret: TokenType.KW_Ret,
  as: TokenType.KW_As,
};

// ── Lexer ───────────────────────────────────────────────────────────
export class Lexer {
  private src: string;
  private pos: number = 0;
  private line: number = 1;
  private col: number = 1;
  private tokens: Token[] = [];

  constructor(source: string) {
    this.src = source;
  }

  tokenize(): Token[] {
    while (this.pos < this.src.length) {
      this.skipSpaces();
      if (this.pos >= this.src.length) break;

      const ch = this.src[this.pos];

      // Newlines
      if (ch === "\n") {
        this.pushTok(TokenType.Newline, "\n", 1);
        this.line++;
        this.col = 1;
        continue;
      }

      // Carriage return
      if (ch === "\r") {
        this.pos++;
        continue;
      }

      // Line comments: #
      if (ch === "#") {
        this.readLineComment();
        continue;
      }

      // Section separator: ---
      if (ch === "-" && this.peek(1) === "-" && this.peek(2) === "-") {
        const start = this.loc();
        let len = 3;
        while (this.peek(len) === "-") len++;
        this.pushTok(TokenType.Dash3, this.src.slice(this.pos, this.pos + len), len);
        continue;
      }

      // Strings
      if (ch === '"') {
        this.readString();
        continue;
      }
      if (ch === "'") {
        // Could be a prime or a single-quoted string — we treat ' as prime
        this.pushTok(TokenType.Prime, "'", 1);
        continue;
      }

      // !! (must check before single !)
      if (ch === "!" && this.peek(1) === "!") {
        this.pushTok(TokenType.Bang2, "!!", 2);
        continue;
      }
      if (ch === "!" && this.peek(1) === "=") {
        this.pushTok(TokenType.NotEq, "!=", 2);
        continue;
      }
      if (ch === "!") {
        this.pushTok(TokenType.Bang, "!", 1);
        continue;
      }

      // Ellipsis
      if (ch === "." && this.peek(1) === "." && this.peek(2) === ".") {
        this.pushTok(TokenType.Ellipsis, "...", 3);
        continue;
      }

      // Arrows and comparison
      if (ch === "-" && this.peek(1) === ">") {
        this.pushTok(TokenType.Arrow, "->", 2);
        continue;
      }
      if (ch === "=" && this.peek(1) === ">") {
        this.pushTok(TokenType.FatArrow, "=>", 2);
        continue;
      }
      if (ch === "=" && this.peek(1) === "=") {
        this.pushTok(TokenType.EqEq, "==", 2);
        continue;
      }
      if (ch === ">" && this.peek(1) === "=") {
        this.pushTok(TokenType.GtEq, ">=", 2);
        continue;
      }
      if (ch === "<" && this.peek(1) === "=") {
        this.pushTok(TokenType.LtEq, "<=", 2);
        continue;
      }

      // Unicode symbols
      if (ch === "∀") { this.pushTok(TokenType.ForAll, "∀", 1); continue; }
      if (ch === "∃") { this.pushTok(TokenType.Exists, "∃", 1); continue; }
      if (ch === "∈") { this.pushTok(TokenType.ElementOf, "∈", 1); continue; }
      if (ch === "⟹") { this.pushTok(TokenType.Implies, "⟹", 1); continue; }
      if (ch === "∑") { this.pushTok(TokenType.Summation, "∑", 1); continue; }
      if (ch === "✓") { this.pushTok(TokenType.Checkmark, "✓", 1); continue; }
      if (ch === "←") { this.pushTok(TokenType.LeftArrow, "←", 1); continue; }

      // Single-char punctuation
      if (ch === "(") { this.pushTok(TokenType.LParen, "(", 1); continue; }
      if (ch === ")") { this.pushTok(TokenType.RParen, ")", 1); continue; }
      if (ch === "{") { this.pushTok(TokenType.LBrace, "{", 1); continue; }
      if (ch === "}") { this.pushTok(TokenType.RBrace, "}", 1); continue; }
      if (ch === "[") { this.pushTok(TokenType.LBracket, "[", 1); continue; }
      if (ch === "]") { this.pushTok(TokenType.RBracket, "]", 1); continue; }
      if (ch === "<") { this.pushTok(TokenType.LAngle, "<", 1); continue; }
      if (ch === ">") { this.pushTok(TokenType.RAngle, ">", 1); continue; }
      if (ch === ":") { this.pushTok(TokenType.Colon, ":", 1); continue; }
      if (ch === ",") { this.pushTok(TokenType.Comma, ",", 1); continue; }
      if (ch === ".") { this.pushTok(TokenType.Dot, ".", 1); continue; }
      if (ch === "?") { this.pushTok(TokenType.Question, "?", 1); continue; }
      if (ch === "|") { this.pushTok(TokenType.Pipe, "|", 1); continue; }
      if (ch === "&" && this.peek(1) === "&") { this.pushTok(TokenType.Ampersand, "&&", 2); continue; }
      if (ch === "&") { this.pushTok(TokenType.Ampersand, "&", 1); continue; }
      if (ch === "+") { this.pushTok(TokenType.Plus, "+", 1); continue; }
      if (ch === "-") { this.pushTok(TokenType.Minus, "-", 1); continue; }
      if (ch === "*") { this.pushTok(TokenType.Star, "*", 1); continue; }
      if (ch === "/") { this.pushTok(TokenType.Slash, "/", 1); continue; }
      if (ch === "=") { this.pushTok(TokenType.Eq, "=", 1); continue; }
      if (ch === ";") { this.pushTok(TokenType.Semicolon, ";", 1); continue; }

      // @ keywords
      if (ch === "@") {
        this.readAtKeyword();
        continue;
      }

      // Numbers
      if (this.isDigit(ch)) {
        this.readNumber();
        continue;
      }

      // Identifiers / plain keywords
      if (this.isIdentStart(ch)) {
        this.readIdentifier();
        continue;
      }

      // Unknown — skip
      this.pos++;
      this.col++;
    }

    this.tokens.push({
      type: TokenType.EOF,
      value: "",
      span: { start: this.loc(), end: this.loc() },
    });

    return this.tokens;
  }

  // ── helpers ─────────────────────────────────────────────────────
  private loc(): Loc {
    return { line: this.line, col: this.col, offset: this.pos };
  }

  private peek(ahead: number = 1): string {
    return this.src[this.pos + ahead] ?? "";
  }

  private pushTok(type: TokenType, value: string, length: number) {
    const start = this.loc();
    this.pos += length;
    this.col += length;
    const end = this.loc();
    this.tokens.push({ type, value, span: { start, end } });
  }

  private skipSpaces() {
    while (this.pos < this.src.length) {
      const ch = this.src[this.pos];
      if (ch === " " || ch === "\t") {
        this.pos++;
        this.col++;
      } else {
        break;
      }
    }
  }

  private readString() {
    const start = this.loc();
    this.pos++; // skip opening "
    this.col++;
    let value = "";
    while (this.pos < this.src.length && this.src[this.pos] !== '"') {
      if (this.src[this.pos] === "\\") {
        this.pos++;
        this.col++;
        value += this.src[this.pos] ?? "";
      } else {
        value += this.src[this.pos];
      }
      if (this.src[this.pos] === "\n") {
        this.line++;
        this.col = 0;
      }
      this.pos++;
      this.col++;
    }
    if (this.pos < this.src.length) {
      this.pos++; // skip closing "
      this.col++;
    }
    const end = this.loc();
    this.tokens.push({ type: TokenType.String, value, span: { start, end } });
  }

  private readAtKeyword() {
    const start = this.loc();
    let word = "@";
    this.pos++;
    this.col++;
    while (this.pos < this.src.length && (this.isIdentChar(this.src[this.pos]))) {
      word += this.src[this.pos];
      this.pos++;
      this.col++;
    }
    const end = this.loc();
    const type = AT_KEYWORDS[word];
    if (type) {
      this.tokens.push({ type, value: word, span: { start, end } });
    } else {
      // Unknown @ keyword — emit as identifier
      this.tokens.push({ type: TokenType.Identifier, value: word, span: { start, end } });
    }
  }

  private readIdentifier() {
    const start = this.loc();
    let word = "";
    while (this.pos < this.src.length && this.isIdentChar(this.src[this.pos])) {
      word += this.src[this.pos];
      this.pos++;
      this.col++;
    }
    const end = this.loc();
    const type = PLAIN_KEYWORDS[word] ?? TokenType.Identifier;
    this.tokens.push({ type, value: word, span: { start, end } });
  }

  private readNumber() {
    const start = this.loc();
    let num = "";
    while (this.pos < this.src.length && (this.isDigit(this.src[this.pos]) || this.src[this.pos] === ".")) {
      num += this.src[this.pos];
      this.pos++;
      this.col++;
    }
    const end = this.loc();
    this.tokens.push({ type: TokenType.Number, value: num, span: { start, end } });
  }

  private readLineComment() {
    const start = this.loc();
    let text = "";
    this.pos++; // skip #
    this.col++;
    while (this.pos < this.src.length && this.src[this.pos] !== "\n") {
      text += this.src[this.pos];
      this.pos++;
      this.col++;
    }
    const end = this.loc();
    this.tokens.push({ type: TokenType.Hash, value: text.trim(), span: { start, end } });
  }

  private isDigit(ch: string): boolean {
    return ch >= "0" && ch <= "9";
  }

  private isIdentStart(ch: string): boolean {
    return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "_";
  }

  private isIdentChar(ch: string): boolean {
    return this.isIdentStart(ch) || this.isDigit(ch) || ch === "_";
  }
}
