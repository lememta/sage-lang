#!/usr/bin/env bash
set -e

echo "Setting up SAGE VS Code LSP extension..."
echo ""

# Build Lean LSP server
echo "1. Building LSP server..."
lake build sage-lsp
echo "   ✓ LSP server built"
echo ""

# Bundle binary into extension
echo "2. Bundling sage-lsp binary..."
mkdir -p vscode-extension/bin
cp .lake/build/bin/sage-lsp vscode-extension/bin/sage-lsp
chmod +x vscode-extension/bin/sage-lsp
echo "   ✓ Binary bundled"
echo ""

# Install extension
echo "3. Installing extension to VS Code..."
EXT_DIR="$HOME/.vscode/extensions/sage-lang-lsp-0.1.0"
rm -rf "$EXT_DIR"
cp -r vscode-extension "$EXT_DIR"
echo "   ✓ Extension copied to $EXT_DIR"
echo ""

# Install node dependencies
echo "4. Installing node dependencies..."
cd "$EXT_DIR" && npm install --omit=dev --silent
echo "   ✓ Dependencies installed"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Restart VS Code to activate the SAGE Language Server"
