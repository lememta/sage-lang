const path = require('path');
const fs = require('fs');
const { workspace, window } = require('vscode');
const {
    LanguageClient,
    TransportKind
} = require('vscode-languageclient/node');

let client;

function findLSPExecutable() {
    // Check workspace lean/.lake/build/bin
    if (workspace.workspaceFolders) {
        const workspaceRoot = workspace.workspaceFolders[0].uri.fsPath;
        const lakePath = path.join(workspaceRoot, 'lean', '.lake', 'build', 'bin', 'sage-lsp');
        if (fs.existsSync(lakePath)) {
            return lakePath;
        }
        // Also check root .lake/build/bin
        const rootLakePath = path.join(workspaceRoot, '.lake', 'build', 'bin', 'sage-lsp');
        if (fs.existsSync(rootLakePath)) {
            return rootLakePath;
        }
    }
    
    // Fallback to PATH
    return 'sage-lsp';
}

function activate(context) {
    const serverExecutable = findLSPExecutable();
    
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

    client = new LanguageClient(
        'sageLSP',
        'SAGE Language Server',
        serverOptions,
        clientOptions
    );

    client.start();
}

function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}

module.exports = {
    activate,
    deactivate
};
