const path = require('path');
const fs = require('fs');
const vscode = require('vscode');
const { workspace, window, languages, commands, OverviewRulerLane } = vscode;
const {
    LanguageClient,
    TransportKind
} = require('vscode-languageclient/node');

let client;
let verifiedDecorationType;
let failedDecorationType;
let unverifiedDecorationType;

// ─── LSP Server Discovery ───────────────────────────────────────

function findLSPExecutable(context) {
    // 1. Bundled binary inside the extension
    const bundledPath = path.join(context.extensionPath, 'bin', 'sage-lsp');
    if (fs.existsSync(bundledPath)) return bundledPath;

    // 2. Workspace .lake build
    if (workspace.workspaceFolders) {
        const workspaceRoot = workspace.workspaceFolders[0].uri.fsPath;
        const lakePath = path.join(workspaceRoot, 'lean', '.lake', 'build', 'bin', 'sage-lsp');
        if (fs.existsSync(lakePath)) return lakePath;
        const rootLakePath = path.join(workspaceRoot, '.lake', 'build', 'bin', 'sage-lsp');
        if (fs.existsSync(rootLakePath)) return rootLakePath;
    }

    // 3. Fallback to PATH
    return 'sage-lsp';
}

// ─── Client-Side Function Finder ────────────────────────────────

function findFunctionDeclarations(document) {
    const functions = [];
    const fnRegex = /^(\s*)@fn\s+([a-z_][a-zA-Z0-9_]*)/;
    for (let i = 0; i < document.lineCount; i++) {
        const line = document.lineAt(i);
        const match = fnRegex.exec(line.text);
        if (match) {
            functions.push({
                name: match[2],
                line: i,
                range: new vscode.Range(i, match[1].length, i, line.text.length)
            });
        }
    }
    return functions;
}

function findModuleForLine(document, lineNumber) {
    const modRegex = /^\s*@mod\s+([a-z_][a-zA-Z0-9_]*)/;
    for (let i = lineNumber; i >= 0; i--) {
        const match = modRegex.exec(document.lineAt(i).text);
        if (match) return match[1];
    }
    return 'default';
}

function findFunctionAtCursor(document, position) {
    const functions = findFunctionDeclarations(document);
    functions.sort((a, b) => a.line - b.line);
    for (let i = functions.length - 1; i >= 0; i--) {
        if (position.line >= functions[i].line) return functions[i];
    }
    return null;
}

// ─── Decoration Update Logic ────────────────────────────────────

function updateAllDecorations(editor, diagnostics) {
    if (!editor || editor.document.languageId !== 'sage') return;

    const document = editor.document;
    const functions = findFunctionDeclarations(document);

    const verifiedRanges = [];
    const failedRanges = [];
    const unverifiedRanges = [];

    for (const func of functions) {
        const moduleName = findModuleForLine(document, func.line);
        const functionId = `${moduleName}.${func.name}`;

        // Match diagnostics by [module.function] prefix in message
        const funcDiags = diagnostics.filter(d =>
            d.message && d.message.startsWith(`[${functionId}]`)
        );

        if (funcDiags.length === 0) {
            unverifiedRanges.push({
                range: new vscode.Range(func.line, 0, func.line, 0),
                hoverMessage: `${func.name}: not verified`
            });
        } else {
            // severity 1 = error in LSP
            const hasErrors = funcDiags.some(d => d.severity === 1);
            if (hasErrors) {
                const errors = funcDiags
                    .filter(d => d.severity === 1)
                    .map(d => `- ${d.message.replace(`[${functionId}] `, '')}`)
                    .join('\n');
                failedRanges.push({
                    range: new vscode.Range(func.line, 0, func.line, 0),
                    hoverMessage: new vscode.MarkdownString(
                        `**${func.name}**: verification failed\n\n${errors}`
                    )
                });
            } else {
                verifiedRanges.push({
                    range: new vscode.Range(func.line, 0, func.line, 0),
                    hoverMessage: `${func.name}: all checks passed`
                });
            }
        }
    }

    editor.setDecorations(verifiedDecorationType, verifiedRanges);
    editor.setDecorations(failedDecorationType, failedRanges);
    editor.setDecorations(unverifiedDecorationType, unverifiedRanges);
}

// ─── Activation ─────────────────────────────────────────────────

function activate(context) {
    // Create gutter decoration types
    verifiedDecorationType = window.createTextEditorDecorationType({
        gutterIconPath: context.asAbsolutePath('icons/verified.svg'),
        gutterIconSize: '80%',
        overviewRulerColor: '#4caf50',
        overviewRulerLane: OverviewRulerLane.Right
    });
    failedDecorationType = window.createTextEditorDecorationType({
        gutterIconPath: context.asAbsolutePath('icons/failed.svg'),
        gutterIconSize: '80%',
        overviewRulerColor: '#f44336',
        overviewRulerLane: OverviewRulerLane.Right
    });
    unverifiedDecorationType = window.createTextEditorDecorationType({
        gutterIconPath: context.asAbsolutePath('icons/unverified.svg'),
        gutterIconSize: '80%',
        overviewRulerColor: '#9e9e9e',
        overviewRulerLane: OverviewRulerLane.Right
    });

    context.subscriptions.push(verifiedDecorationType, failedDecorationType, unverifiedDecorationType);

    // Start LSP client
    const serverExecutable = findLSPExecutable(context);
    const serverOptions = {
        run: { command: serverExecutable, transport: TransportKind.stdio },
        debug: { command: serverExecutable, transport: TransportKind.stdio }
    };
    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: 'sage' }],
        synchronize: {
            fileEvents: workspace.createFileSystemWatcher('**/*.sage')
        }
    };

    client = new LanguageClient('sageLSP', 'SAGE Language Server', serverOptions, clientOptions);
    client.start();

    // Update decorations when diagnostics change
    languages.onDidChangeDiagnostics((event) => {
        for (const uri of event.uris) {
            const editor = window.visibleTextEditors.find(
                e => e.document.uri.toString() === uri.toString()
            );
            if (editor && editor.document.languageId === 'sage') {
                const diags = languages.getDiagnostics(uri);
                // Convert from VS Code Diagnostic[] to plain objects for our matcher
                const plainDiags = diags.map(d => ({
                    severity: d.severity === vscode.DiagnosticSeverity.Error ? 1
                            : d.severity === vscode.DiagnosticSeverity.Warning ? 2
                            : d.severity === vscode.DiagnosticSeverity.Information ? 3
                            : 4,
                    message: d.message
                }));
                updateAllDecorations(editor, plainDiags);
            }
        }
    }, null, context.subscriptions);

    // Reapply decorations on tab switch
    window.onDidChangeActiveTextEditor(editor => {
        if (editor && editor.document.languageId === 'sage') {
            const diags = languages.getDiagnostics(editor.document.uri);
            const plainDiags = diags.map(d => ({
                severity: d.severity === vscode.DiagnosticSeverity.Error ? 1
                        : d.severity === vscode.DiagnosticSeverity.Warning ? 2
                        : d.severity === vscode.DiagnosticSeverity.Information ? 3
                        : 4,
                message: d.message
            }));
            updateAllDecorations(editor, plainDiags);
        }
    }, null, context.subscriptions);

    // Register "Verify Contract" command
    const verifyCommand = commands.registerCommand('sage.verifyContract', async () => {
        const editor = window.activeTextEditor;
        if (!editor || editor.document.languageId !== 'sage') {
            window.showWarningMessage('Verify Contract is only available in .sage files.');
            return;
        }

        const func = findFunctionAtCursor(editor.document, editor.selection.active);
        if (!func) {
            window.showWarningMessage('No @fn declaration found at cursor position.');
            return;
        }

        const moduleName = findModuleForLine(editor.document, func.line);

        await window.withProgress(
            { location: vscode.ProgressLocation.Notification, title: `Verifying ${func.name}...` },
            async () => {
                try {
                    const result = await client.sendRequest('sage/verifyFunction', {
                        textDocument: { uri: editor.document.uri.toString() },
                        functionName: func.name,
                        moduleName: moduleName
                    });

                    if (result.status === 'verified') {
                        const msgs = (result.messages || [])
                            .map(m => m.message)
                            .join('\n');
                        window.showInformationMessage(
                            `${func.name}: All verification checks passed.${msgs ? '\n' + msgs : ''}`
                        );
                    } else if (result.status === 'failed') {
                        const errors = (result.messages || [])
                            .filter(m => m.severity === 1)
                            .map(m => m.message)
                            .join('; ');
                        window.showErrorMessage(`${func.name}: Verification failed. ${errors}`);
                    } else {
                        window.showErrorMessage(
                            `${func.name}: ${result.error || 'Unknown error'}`
                        );
                    }
                } catch (err) {
                    window.showErrorMessage(`Verification error: ${err.message || err}`);
                }
            }
        );
    });

    context.subscriptions.push(verifyCommand);
}

function deactivate() {
    if (!client) return undefined;
    return client.stop();
}

module.exports = { activate, deactivate };
