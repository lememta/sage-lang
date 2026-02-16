import Sage.LSP.Types
import Sage.LSP.Analysis
import Lean.Data.Json
import Lean.Data.Json.Parser

open Lean SageLSP

namespace SageLSP

structure ServerState where
  documents : List DocumentState := []
  deriving Inhabited

def ServerState.getDocument (state : ServerState) (uri : String) : Option DocumentState :=
  state.documents.find? (·.uri == uri)

def ServerState.updateDocument (state : ServerState) (doc : DocumentState) : ServerState :=
  { state with documents := doc :: state.documents.filter (·.uri != doc.uri) }

structure JsonRpcRequest where
  jsonrpc : String
  id : Json
  method : String
  params : Json
  deriving ToJson, FromJson

structure JsonRpcResponse where
  jsonrpc : String
  id : Json
  result : Json
  deriving ToJson, FromJson

structure JsonRpcNotification where
  jsonrpc : String
  method : String
  params : Json
  deriving ToJson, FromJson

def handleRequest (state : ServerState) (req : JsonRpcRequest) : IO (ServerState × Option JsonRpcResponse) := do
  match req.method with
  | "initialize" =>
    let result := Json.mkObj [
      ("capabilities", Json.mkObj [
        ("textDocumentSync", Json.num 1),
        ("diagnosticProvider", Json.mkObj [("interFileDependencies", Json.bool false)])
      ])
    ]
    pure (state, some { jsonrpc := "2.0", id := req.id, result := result })
  
  | "shutdown" =>
    pure (state, some { jsonrpc := "2.0", id := req.id, result := Json.null })
  
  | "textDocument/diagnostic" =>
    match req.params.getObjValAs? TextDocumentIdentifier "textDocument" with
    | .ok docId =>
      match state.getDocument docId.uri with
      | some doc =>
        let diagnostics := analyzeSage doc.text
        let result := Json.mkObj [
          ("kind", Json.str "full"),
          ("items", Json.arr (diagnostics.map toJson).toArray)
        ]
        pure (state, some { jsonrpc := "2.0", id := req.id, result := result })
      | none =>
        pure (state, some { jsonrpc := "2.0", id := req.id, result := Json.mkObj [("kind", Json.str "full"), ("items", Json.arr #[])] })
    | .error _ =>
      pure (state, some { jsonrpc := "2.0", id := req.id, result := Json.mkObj [("kind", Json.str "full"), ("items", Json.arr #[])] })
  
  | _ =>
    pure (state, some { jsonrpc := "2.0", id := req.id, result := Json.null })

def handleNotification (state : ServerState) (notif : JsonRpcNotification) : IO ServerState := do
  match notif.method with
  | "textDocument/didOpen" =>
    match notif.params.getObjValAs? TextDocumentItem "textDocument" with
    | .ok doc =>
      let docState : DocumentState := {
        uri := doc.uri
        text := doc.text
        version := doc.version
        diagnostics := analyzeSage doc.text
      }
      pure (state.updateDocument docState)
    | .error _ => pure state
  
  | "textDocument/didChange" =>
    match notif.params.getObjValAs? TextDocumentIdentifier "textDocument" with
    | .ok docId =>
      match notif.params.getObjValAs? (Array Json) "contentChanges" with
      | .ok changes =>
        if h : changes.size > 0 then
          match changes[0].getObjValAs? String "text" with
          | .ok text =>
            match state.getDocument docId.uri with
            | some doc =>
              let newDoc := doc.update text (doc.version + 1)
              let newDoc := { newDoc with diagnostics := analyzeSage text }
              pure (state.updateDocument newDoc)
            | none => pure state
          | .error _ => pure state
        else pure state
      | .error _ => pure state
    | .error _ => pure state
  
  | "textDocument/didClose" =>
    match notif.params.getObjValAs? TextDocumentIdentifier "textDocument" with
    | .ok docId =>
      pure { state with documents := state.documents.filter (·.uri != docId.uri) }
    | .error _ => pure state
  
  | _ => pure state

def readMessage (stream : IO.FS.Stream) : IO (Option String) := do
  let mut headers : List (String × String) := []
  
  -- Read headers
  repeat
    let line ← stream.getLine
    let line := line.trimAscii.toString
    if line.isEmpty then break
    match line.splitOn ":" with
    | [key, value] => headers := (key.trimAscii.toString, value.trimAscii.toString) :: headers
    | _ => pure ()
  
  -- Get content length
  match headers.find? (·.1 == "Content-Length") with
  | some (_, lenStr) =>
    match lenStr.toNat? with
    | some len =>
      let content ← stream.read len.toUSize
      pure (some (String.fromUTF8! content))
    | none => pure none
  | none => pure none

def writeMessage (stream : IO.FS.Stream) (content : String) : IO Unit := do
  let header := s!"Content-Length: {content.utf8ByteSize}\r\n\r\n"
  stream.putStr header
  stream.putStr content
  stream.flush

def runServer : IO Unit := do
  let mut state : ServerState := {}
  
  repeat
    match ← readMessage (← IO.getStdin) with
    | none => break
    | some msg =>
      match Json.parse msg with
      | .error _ => continue
      | .ok json =>
        -- Try as request
        match fromJson? json with
        | .ok (req : JsonRpcRequest) =>
          let (newState, resp) ← handleRequest state req
          state := newState
          match resp with
          | some r =>
            let stdout ← IO.getStdout
            writeMessage stdout (toJson r).compress
          | none => pure ()
        | .error _ =>
          -- Try as notification
          match fromJson? json with
          | .ok (notif : JsonRpcNotification) =>
            state ← handleNotification state notif
          | .error _ => continue

end SageLSP
