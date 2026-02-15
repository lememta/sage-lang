// ── Source location ──────────────────────────────────────────────────
export interface Loc {
  line: number;
  col: number;
  offset: number;
}

export interface Span {
  start: Loc;
  end: Loc;
}

// ── Top-level AST ───────────────────────────────────────────────────
export interface SageFile {
  kind: "File";
  body: TopLevel[];
  span: Span;
}

export type TopLevel =
  | ModuleDecl
  | TypeDecl
  | FnDecl
  | SpecDecl
  | OpDecl
  | RefineDecl
  | ImplDecl
  | NaturalText
  | DecisionMarker
  | SectionSeparator
  | InferredAnnotation
  | LetBinding
  | IfExpr
  | RetStatement
  | Comment
  | RawExpression;

// ── Declarations ────────────────────────────────────────────────────
export interface ModuleDecl {
  kind: "ModuleDecl";
  name: string;
  description?: string;
  span: Span;
}

export interface TypeDecl {
  kind: "TypeDecl";
  name: string;
  fields: FieldDef[];
  span: Span;
}

export interface FieldDef {
  kind: "FieldDef";
  name: string;
  type: TypeExpr;
  span: Span;
}

export type TypeExpr =
  | NamedType
  | GenericType
  | RecordType;

export interface NamedType {
  kind: "NamedType";
  name: string;
  span: Span;
}

export interface GenericType {
  kind: "GenericType";
  name: string;
  args: TypeExpr[];
  span: Span;
}

export interface RecordType {
  kind: "RecordType";
  fields: FieldDef[];
  span: Span;
}

// ── Function declarations ───────────────────────────────────────────
export interface Param {
  kind: "Param";
  name: string;
  type?: TypeExpr;
  span: Span;
}

export interface FnDecl {
  kind: "FnDecl";
  name: string;
  params: Param[];
  returnType?: TypeExpr;
  description?: string;
  requires: Requirement[];
  ensures: Ensures[];
  body: Statement[];
  span: Span;
}

export interface Requirement {
  kind: "Requirement";
  condition: string; // raw expression or natural language string
  span: Span;
}

export interface Ensures {
  kind: "Ensures";
  condition: string;
  span: Span;
}

// ── Spec declarations ───────────────────────────────────────────────
export interface SpecDecl {
  kind: "SpecDecl";
  name: string;
  description?: string;
  properties: Property[];
  state: StateField[];
  invariants: Invariant[];
  span: Span;
}

export interface Property {
  kind: "Property";
  description: string;
  span: Span;
}

export interface StateField {
  kind: "StateField";
  name: string;
  type: TypeExpr;
  span: Span;
}

export interface Invariant {
  kind: "Invariant";
  expression: string;
  span: Span;
}

// ── Operations ──────────────────────────────────────────────────────
export interface OpDecl {
  kind: "OpDecl";
  name: string;
  params: Param[];
  returnType?: TypeExpr;
  requires: Requirement[];
  ensures: Ensures[];
  body: Statement[];
  span: Span;
}

// ── Refinement ──────────────────────────────────────────────────────
export interface RefineDecl {
  kind: "RefineDecl";
  parent: string;
  child?: string;
  tag?: string; // e.g. "alternative"
  decisions: DecisionMarker[];
  state: StateField[];
  preserves: Preserves[];
  maps: MapsClause[];
  compareWith?: CompareWith;
  description?: string;
  span: Span;
}

export interface DecisionMarker {
  kind: "DecisionMarker";
  text: string;
  span: Span;
}

export interface Preserves {
  kind: "Preserves";
  description: string;
  checked: boolean; // has ✓ prefix
  span: Span;
}

export interface MapsClause {
  kind: "MapsClause";
  description: string;
  span: Span;
}

export interface CompareWith {
  kind: "CompareWith";
  target: string;
  advantages?: string;
  disadvantages?: string;
  span: Span;
}

// ── Implementation ──────────────────────────────────────────────────
export interface ImplDecl {
  kind: "ImplDecl";
  spec?: string;
  body: string; // raw text
  span: Span;
}

// ── Statements / Expressions ────────────────────────────────────────
export type Statement =
  | LetBinding
  | IfExpr
  | RetStatement
  | NaturalText
  | DecisionMarker
  | RawExpression;

export interface LetBinding {
  kind: "LetBinding";
  name: string;
  value: string; // raw expression text
  decision: boolean; // prefixed with !!
  span: Span;
}

export interface IfExpr {
  kind: "IfExpr";
  condition: string;
  then: string;
  else?: string;
  decision: boolean;
  span: Span;
}

export interface RetStatement {
  kind: "RetStatement";
  value: string;
  span: Span;
}

export interface RawExpression {
  kind: "RawExpression";
  text: string;
  span: Span;
}

// ── Misc ────────────────────────────────────────────────────────────
export interface NaturalText {
  kind: "NaturalText";
  text: string;
  span: Span;
}

export interface SectionSeparator {
  kind: "SectionSeparator";
  span: Span;
}

export interface InferredAnnotation {
  kind: "InferredAnnotation";
  type: "req" | "ens" | "effect";
  condition: string;
  reason?: string;
  span: Span;
}

export interface Comment {
  kind: "Comment";
  text: string;
  span: Span;
}
