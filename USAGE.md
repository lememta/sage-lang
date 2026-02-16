# SAGE Lean Implementation - Usage Guide

## Quick Start (3 Steps)

### 1. Build
```bash
cd lean
./build.sh
```

### 2. Install VS Code Extension
```bash
cd ..
./scripts/setup-vscode-lsp.sh
```

### 3. Use
Restart VS Code and open any `.sage` file!

---

## Detailed Usage

### Compiler CLI

**Basic usage:**
```bash
cd lean
.lake/build/bin/sage <file.sage>
```

**Examples:**
```bash
# Compile a natural language spec
.lake/build/bin/sage ../examples/level0-natural.sage

# Compile a structured spec
.lake/build/bin/sage ../examples/level1-structured.sage

# Compile a formal spec
.lake/build/bin/sage ../examples/level2-formal.sage
```

**Output:**
```
Compiled successfully: 1 module(s)
Module: payment_service
  Types: 2
  Functions: 1
```

### Language Server (LSP)

The LSP server runs automatically when you open a `.sage` file in VS Code.

**Manual testing:**
```bash
cd lean
.lake/build/bin/sage-lsp
```

Then send JSON-RPC messages via stdin:
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
```

**VS Code Integration:**
- Opens automatically when you open a `.sage` file
- Provides real-time diagnostics
- Shows errors as red squiggles
- Updates on file save

### VS Code Extension

**Features:**
- ✅ Syntax highlighting for all SAGE constructs
- ✅ Real-time error checking
- ✅ Parse error diagnostics
- ✅ Type error diagnostics
- ✅ File watching and auto-update

**Configuration:**

Open VS Code settings (Cmd+,) and search for "SAGE":

```json
{
  "sage.trace.server": "off"  // or "messages" or "verbose"
}
```

**Viewing LSP Logs:**
1. View → Output
2. Select "SAGE Language Server" from dropdown
3. See server startup and diagnostic messages

**Troubleshooting:**
```bash
# Check extension is installed
ls -la ~/.vscode/extensions/sage-lang-lsp-0.1.0

# Check LSP server exists
ls -la lean/.lake/build/bin/sage-lsp

# Reinstall extension
./scripts/setup-vscode-lsp.sh

# Reload VS Code
Cmd+Shift+P → "Developer: Reload Window"
```

## Development Workflow

### 1. Modify Compiler

**Edit source:**
```bash
# Edit any file in lean/Sage/
vim lean/Sage/Lexer.lean
```

**Rebuild:**
```bash
cd lean
lake build sage
```

**Test:**
```bash
.lake/build/bin/sage test.sage
```

### 2. Modify LSP Server

**Edit source:**
```bash
# Edit any file in lean/Sage/LSP/
vim lean/Sage/LSP/Server.lean
```

**Rebuild:**
```bash
cd lean
lake build sage-lsp
```

**Test:**
```bash
# Reload VS Code to restart LSP
Cmd+Shift+P → "Developer: Reload Window"
```

### 3. Modify VS Code Extension

**Edit source:**
```bash
# Edit extension files
vim packages/vscode-lsp/client/extension.js
```

**Reinstall:**
```bash
./scripts/setup-vscode-lsp.sh
```

**Test:**
```bash
# Reload VS Code
Cmd+Shift+P → "Developer: Reload Window"
```

## Build Commands

### Full Build
```bash
cd lean
./build.sh
```

### Individual Targets
```bash
# Compiler only
lake build sage

# LSP server only
lake build sage-lsp

# Both
lake build
```

### Clean Build
```bash
lake clean
lake build
```

### Check Build Status
```bash
# List built executables
ls -lh .lake/build/bin/

# Check compiler
.lake/build/bin/sage --help || echo "Compiler built"

# Check LSP
file .lake/build/bin/sage-lsp
```

## Testing

### Test Compiler

**Test all examples:**
```bash
cd lean
for f in ../examples/*.sage; do
  echo "Testing $f..."
  .lake/build/bin/sage "$f"
done
```

**Test specific file:**
```bash
.lake/build/bin/sage ../examples/level1-structured.sage
```

**Expected output:**
```
Compiled successfully: 1 module(s)
Module: payment_service
  Types: 2
  Functions: 1
```

### Test LSP

**Method 1: VS Code**
1. Open VS Code
2. Open a `.sage` file
3. Check bottom bar for "SAGE Language Server"
4. Introduce an error and check for red squiggles

**Method 2: Manual**
```bash
cd lean
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | .lake/build/bin/sage-lsp
```

**Expected output:**
```
SAGE Language Server starting...
Content-Length: 123

{"jsonrpc":"2.0","id":1,"result":{"capabilities":...}}
```

### Test Extension

**Check installation:**
```bash
ls -la ~/.vscode/extensions/sage-lang-lsp-0.1.0
```

**Check dependencies:**
```bash
cd packages/vscode-lsp/client
npm list
```

**Check syntax highlighting:**
1. Open a `.sage` file in VS Code
2. Verify keywords are colored
3. Verify strings are colored
4. Verify comments are colored

## Common Tasks

### Add New Language Feature

1. **Add token type** (`Sage/Token.lean`)
   ```lean
   | myNewKeyword
   ```

2. **Update lexer** (`Sage/Lexer.lean`)
   ```lean
   -- Add tokenization logic
   ```

3. **Add AST node** (`Sage/AST.lean`)
   ```lean
   inductive MyNewNode where
     | ...
   ```

4. **Update parser** (`Sage/Parser.lean`)
   ```lean
   -- Add parsing logic
   ```

5. **Update type checker** (`Sage/TypeCheck.lean`)
   ```lean
   -- Add type checking logic
   ```

6. **Rebuild and test**
   ```bash
   cd lean
   lake build
   .lake/build/bin/sage test.sage
   ```

### Update LSP Diagnostics

1. **Edit analysis** (`Sage/LSP/Analysis.lean`)
   ```lean
   def analyzeSage (text : String) : List Diagnostic := ...
   ```

2. **Rebuild LSP**
   ```bash
   cd lean
   lake build sage-lsp
   ```

3. **Test in VS Code**
   - Reload window
   - Open `.sage` file
   - Check diagnostics

### Update Syntax Highlighting

1. **Edit grammar** (`packages/vscode-lsp/syntaxes/sage.tmLanguage.json`)
   ```json
   {
     "match": "\\b(myNewKeyword)\\b",
     "name": "keyword.control.sage"
   }
   ```

2. **Reinstall extension**
   ```bash
   ./scripts/setup-vscode-lsp.sh
   ```

3. **Test in VS Code**
   - Reload window
   - Check highlighting

## Performance

### Build Times
- Clean build: ~10 seconds
- Incremental build: ~2 seconds
- LSP rebuild: ~5 seconds

### Executable Sizes
- Compiler: 2.1 MB
- LSP Server: 102 MB (includes Lean runtime)

### Runtime Performance
- Compiler: Fast (skeleton implementation)
- LSP: Responsive (real-time diagnostics)

## Troubleshooting

### Build Fails

**Check Lean installation:**
```bash
lean --version
lake --version
```

**Clean and rebuild:**
```bash
cd lean
lake clean
lake build
```

**Check for errors:**
```bash
lake build 2>&1 | grep error
```

### LSP Not Working

**Check server is built:**
```bash
ls -la lean/.lake/build/bin/sage-lsp
```

**Check VS Code logs:**
- View → Output → "SAGE Language Server"

**Test server manually:**
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | lean/.lake/build/bin/sage-lsp
```

**Restart VS Code:**
- Cmd+Shift+P → "Developer: Reload Window"

### Extension Not Loading

**Check installation:**
```bash
ls -la ~/.vscode/extensions/sage-lang-lsp-0.1.0
```

**Check dependencies:**
```bash
cd packages/vscode-lsp/client
npm install
```

**Reinstall:**
```bash
./scripts/setup-vscode-lsp.sh
```

**Check VS Code console:**
- Help → Toggle Developer Tools
- Check Console tab for errors

## Resources

- **Lean Documentation**: https://leanprover.github.io/lean4/doc/
- **Lake Build System**: https://github.com/leanprover/lake
- **LSP Specification**: https://microsoft.github.io/language-server-protocol/
- **VS Code Extension API**: https://code.visualstudio.com/api
- **SAGE Language Spec**: `../SAGE_SPEC.md`
- **Design Philosophy**: `../DESIGN.md`

## Getting Help

1. Check the [README](README.md)
2. Check the [Quick Start](QUICKSTART.md)
3. Check the [Migration Guide](../LEAN_MIGRATION.md)
4. Open an issue on GitHub

---

**Happy SAGE coding!** 🌿
