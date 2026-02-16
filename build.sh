#!/usr/bin/env bash
set -e

echo "=== Building SAGE Language (Lean) ==="
echo ""

# Build compiler
echo "1. Building SAGE compiler..."
lake build sage
echo "   ✓ Compiler built: .lake/build/bin/sage"
echo ""

# Build LSP
echo "2. Building SAGE Language Server..."
lake build sage-lsp
echo "   ✓ LSP built: .lake/build/bin/sage-lsp"
echo ""

echo "=== Build Complete ==="
echo ""
echo "Usage:"
echo "  Compiler:  .lake/build/bin/sage <file.sage>"
echo "  LSP:       .lake/build/bin/sage-lsp"
