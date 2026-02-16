# Quick Start: SAGE with Lean & VS Code LSP

This guide will get you up and running with the SAGE language using the Lean implementation and VS Code Language Server.

## Prerequisites

1. **Lean 4** - Install from [leanprover.github.io](https://leanprover.github.io/lean4/doc/setup.html)
   ```bash
   # macOS
   curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
   
   # Verify installation
   lean --version
   ```

2. **Node.js** - For VS Code extension (v16 or later)
   ```bash
   node --version
   ```

3. **VS Code** - Download from [code.visualstudio.com](https://code.visualstudio.com/)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/sage-lang.git
cd sage-lang
```

### 2. Build the Lean Compiler & LSP

```bash
cd lean
./build.sh
cd ..
```

This builds:
- `.lake/build/bin/sage` - The SAGE compiler
- `.lake/build/bin/sage-lsp` - The Language Server

### 3. Install VS Code Extension

```bash
./scripts/setup-vscode-lsp.sh
```

This will:
- Install extension dependencies
- Copy the extension to VS Code
- Configure the LSP server path

### 4. Restart VS Code

Close and reopen VS Code to activate the extension.

## Usage

### 1. Create a SAGE File

Create a new file `hello.sage`:

```sage
@mod hello

"A simple greeting function"

@type Greeting = {
  message: Str,
  recipient: Str
}

@fn greet(name: Str) -> Greeting
@req name.len() > 0
@ens "Returns a greeting with the given name"

!! "Keep greetings friendly and professional"
```

### 2. Open in VS Code

```bash
code hello.sage
```

You should see:
- ✅ Syntax highlighting
- ✅ Real-time diagnostics (if there are errors)
- ✅ Language server status in the bottom bar

### 3. Compile from Command Line

```bash
cd lean
.lake/build/bin/sage ../hello.sage
```

## Features

### Syntax Highlighting

The extension provides color coding for:
- Keywords (`@mod`, `@type`, `@fn`, etc.)
- Strings and natural language specs
- Types and identifiers
- Operators and punctuation
- Important decisions (`!!`)

### Real-time Diagnostics

As you type, the LSP server analyzes your code and shows:
- Parse errors
- Type errors
- Semantic issues

Errors appear as red squiggles with hover tooltips.

### File Watching

The extension automatically updates when you:
- Open a `.sage` file
- Edit and save
- Switch between files

## Examples

Try the included examples:

```bash
# Level 0: Natural language
code examples/level0-natural.sage

# Level 1: Structured specs
code examples/level1-structured.sage

# Level 2: Formal specifications
code examples/level2-formal.sage
```

## Troubleshooting

### LSP Server Not Starting

1. Check the server is built:
   ```bash
   ls -la lean/.lake/build/bin/sage-lsp
   ```

2. View LSP logs in VS Code:
   - View → Output
   - Select "SAGE Language Server" from dropdown

3. Check for errors:
   - Help → Toggle Developer Tools
   - Look in Console tab

### No Syntax Highlighting

1. Verify extension is installed:
   ```bash
   ls -la ~/.vscode/extensions/sage-lang-lsp-0.1.0
   ```

2. Check file association:
   - File should have `.sage` extension
   - Bottom right of VS Code should show "SAGE"

3. Reload VS Code:
   - Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows/Linux)
   - Type "Developer: Reload Window"

### Extension Not Loading

1. Check Node.js version:
   ```bash
   node --version  # Should be v16 or later
   ```

2. Reinstall dependencies:
   ```bash
   cd packages/vscode-lsp/client
   rm -rf node_modules
   npm install
   ```

3. Reinstall extension:
   ```bash
   ./scripts/setup-vscode-lsp.sh
   ```

## Next Steps

- Read the [Language Specification](../SAGE_SPEC.md)
- Explore [Design Philosophy](../DESIGN.md)
- Check out the [Tutorial](../docs/tutorial.md)
- Review [Lean Implementation Details](README.md)

## Development

### Modify the Compiler

1. Edit files in `lean/Sage/`
2. Rebuild: `cd lean && lake build`
3. Test: `.lake/build/bin/sage test.sage`

### Modify the LSP

1. Edit files in `lean/Sage/LSP/`
2. Rebuild: `cd lean && lake build sage-lsp`
3. Reload VS Code to restart the server

### Modify the Extension

1. Edit files in `packages/vscode-lsp/`
2. Reinstall: `./scripts/setup-vscode-lsp.sh`
3. Reload VS Code

## Getting Help

- Check the [Lean README](README.md) for detailed documentation
- Review the [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- Open an issue on GitHub

Happy SAGE coding! 🌿
