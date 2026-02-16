#!/usr/bin/env bash
set -e

echo "Setting up SAGE VS Code LSP extension..."
echo ""

# Build Lean LSP server
echo "1. Building LSP server..."
lake build sage-lsp
echo "   ✓ LSP server built"
echo ""

# Install extension
echo "2. Installing extension to VS Code..."
EXT_DIR="$HOME/.vscode/extensions/sage-lang-lsp-0.1.0"
rm -rf "$EXT_DIR"
cp -r vscode-extension "$EXT_DIR"
echo "   ✓ Extension installed to $EXT_DIR"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Restart VS Code to activate the SAGE Language Server"
